package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// version is set at build time: -ldflags "-X main.version=<commit>".
var version = "dev"

func env(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	if v := os.Getenv("GIT_COMMIT"); v != "" {
		version = v
	}

	dsn := url.URL{
		Scheme:   "postgres",
		User:     url.UserPassword(env("POSTGRES_USER", "dhaba"), os.Getenv("POSTGRES_PASSWORD")),
		Host:     env("POSTGRES_HOST", "postgres") + ":5432",
		Path:     env("POSTGRES_DB", "dhaba"),
		RawQuery: "sslmode=disable",
	}

	// The pool connects lazily, so the API starts even while Postgres is restarting.
	pool, err := pgxpool.New(context.Background(), dsn.String())
	if err != nil {
		log.Fatalf("postgres config: %v", err)
	}
	defer pool.Close()

	rdb := redis.NewClient(&redis.Options{Addr: env("REDIS_HOST", "redis") + ":6379"})
	defer func() { _ = rdb.Close() }()

	app := &Server{store: &PGStore{pool: pool}, queue: &RedisQueue{rdb: rdb}}
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           app.routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()
	log.Printf("orders-api %s listening on :8080", version)

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	// Give Kubernetes time to remove this pod from the Service before closing,
	// so rolling updates do not drop requests.
	time.Sleep(5 * time.Second)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}
