package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type fakeStore struct{}

func (fakeStore) Insert(_ context.Context, items []Item) (Order, error) {
	return Order{ID: 1, Items: items, Status: "new", CreatedAt: time.Now()}, nil
}

func (fakeStore) Get(_ context.Context, _ int) (Order, error) { return Order{}, errNotFound }

func (fakeStore) List(_ context.Context, _ int) ([]Order, error) { return []Order{}, nil }

type fakeQueue struct{ queued []int }

func (q *fakeQueue) Enqueue(_ context.Context, o Order) error {
	q.queued = append(q.queued, o.ID)
	return nil
}

func do(t *testing.T, s *Server, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	rec := httptest.NewRecorder()
	s.routes().ServeHTTP(rec, req)
	return rec
}

func TestValidateItems(t *testing.T) {
	cases := []struct {
		name  string
		items []Item
		ok    bool
	}{
		{"valid", []Item{{Name: "Biryani", Qty: 2}}, true},
		{"empty order", nil, false},
		{"blank name", []Item{{Name: " ", Qty: 1}}, false},
		{"zero quantity", []Item{{Name: "Naan", Qty: 0}}, false},
		{"too many of one dish", []Item{{Name: "Naan", Qty: 99}}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if err := validateItems(c.items); (err == nil) != c.ok {
				t.Fatalf("validateItems() error = %v, want ok=%v", err, c.ok)
			}
		})
	}
}

func TestCreateOrderQueuesJob(t *testing.T) {
	q := &fakeQueue{}
	s := &Server{store: fakeStore{}, queue: q}
	rec := do(t, s, http.MethodPost, "/api/orders", `{"items":[{"name":"Biryani","qty":1}]}`)
	if rec.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201, body %s", rec.Code, rec.Body)
	}
	if len(q.queued) != 1 || q.queued[0] != 1 {
		t.Fatalf("queued = %v, want [1]", q.queued)
	}
}

func TestCreateOrderRejectsBadInput(t *testing.T) {
	s := &Server{store: fakeStore{}, queue: &fakeQueue{}}
	for _, body := range []string{`not json`, `{"items":[]}`, `{"items":[{"name":"Naan","qty":0}]}`} {
		if rec := do(t, s, http.MethodPost, "/api/orders", body); rec.Code != http.StatusBadRequest {
			t.Errorf("body %q: status = %d, want 400", body, rec.Code)
		}
	}
}

func TestGetOrderNotFound(t *testing.T) {
	s := &Server{store: fakeStore{}, queue: &fakeQueue{}}
	if rec := do(t, s, http.MethodGet, "/api/orders/7", ""); rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
	}
	if rec := do(t, s, http.MethodGet, "/api/orders/abc", ""); rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want 400", rec.Code)
	}
}

func TestInfoAndHealth(t *testing.T) {
	s := &Server{store: fakeStore{}, queue: &fakeQueue{}}
	version = "abc123"
	rec := do(t, s, http.MethodGet, "/info", "")
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "abc123") {
		t.Fatalf("/info = %d %s", rec.Code, rec.Body)
	}
	if rec := do(t, s, http.MethodGet, "/api/orders/info", ""); rec.Code != http.StatusOK {
		t.Fatalf("/api/orders/info = %d", rec.Code)
	}
	if rec := do(t, s, http.MethodGet, "/health", ""); rec.Code != http.StatusOK {
		t.Fatalf("/health = %d", rec.Code)
	}
}
