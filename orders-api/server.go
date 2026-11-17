package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	maxItemsPerOrder = 20
	maxQtyPerItem    = 20
)

// Item is one dish in an order.
type Item struct {
	Name string `json:"name"`
	Qty  int    `json:"qty"`
}

// Order is a saved order.
type Order struct {
	ID        int       `json:"id"`
	Items     []Item    `json:"items"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// Store saves and reads orders.
type Store interface {
	Insert(ctx context.Context, items []Item) (Order, error)
	Get(ctx context.Context, id int) (Order, error)
	List(ctx context.Context, limit int) ([]Order, error)
}

// Queue hands new orders to the kitchen and records statistics.
type Queue interface {
	Enqueue(ctx context.Context, o Order) error
}

var errNotFound = errors.New("order not found")

// Server holds the HTTP handlers.
type Server struct {
	store Store
	queue Queue
}

func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", s.health)
	mux.HandleFunc("GET /info", s.info)
	mux.HandleFunc("GET /api/orders/info", s.info) // reachable through the ingress
	mux.HandleFunc("POST /api/orders", s.createOrder)
	mux.HandleFunc("GET /api/orders", s.listOrders)
	mux.HandleFunc("GET /api/orders/{id}", s.getOrder)
	return mux
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func validateItems(items []Item) error {
	if len(items) == 0 {
		return errors.New("an order needs at least one item")
	}
	if len(items) > maxItemsPerOrder {
		return fmt.Errorf("an order can have at most %d items", maxItemsPerOrder)
	}
	for _, it := range items {
		if strings.TrimSpace(it.Name) == "" {
			return errors.New("every item needs a name")
		}
		if it.Qty < 1 || it.Qty > maxQtyPerItem {
			return fmt.Errorf("quantity for %q must be between 1 and %d", it.Name, maxQtyPerItem)
		}
	}
	return nil
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) info(w http.ResponseWriter, _ *http.Request) {
	pod, _ := os.Hostname()
	writeJSON(w, http.StatusOK, map[string]string{"version": version, "pod": pod})
}

func (s *Server) createOrder(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var req struct {
		Items []Item `json:"items"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "request body must be JSON like {\"items\":[{\"name\":\"Biryani\",\"qty\":1}]}")
		return
	}
	if err := validateItems(req.Items); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	order, err := s.store.Insert(r.Context(), req.Items)
	if err != nil {
		log.Printf("insert order: %v", err)
		writeError(w, http.StatusServiceUnavailable, "could not save the order, try again")
		return
	}
	if err := s.queue.Enqueue(r.Context(), order); err != nil {
		log.Printf("enqueue order %d: %v", order.ID, err)
		writeError(w, http.StatusServiceUnavailable, "order saved but the kitchen queue is unavailable")
		return
	}
	writeJSON(w, http.StatusCreated, order)
}

func (s *Server) listOrders(w http.ResponseWriter, r *http.Request) {
	orders, err := s.store.List(r.Context(), 50)
	if err != nil {
		log.Printf("list orders: %v", err)
		writeError(w, http.StatusServiceUnavailable, "orders are unavailable")
		return
	}
	writeJSON(w, http.StatusOK, orders)
}

func (s *Server) getOrder(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "order id must be a number")
		return
	}
	order, err := s.store.Get(r.Context(), id)
	if errors.Is(err, errNotFound) {
		writeError(w, http.StatusNotFound, "order not found")
		return
	}
	if err != nil {
		log.Printf("get order %d: %v", id, err)
		writeError(w, http.StatusServiceUnavailable, "orders are unavailable")
		return
	}
	writeJSON(w, http.StatusOK, order)
}
