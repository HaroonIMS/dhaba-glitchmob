package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// PGStore keeps orders in Postgres.
type PGStore struct {
	pool *pgxpool.Pool
}

func scanOrder(row pgx.Row) (Order, error) {
	var (
		o   Order
		raw []byte
	)
	if err := row.Scan(&o.ID, &raw, &o.Status, &o.CreatedAt); err != nil {
		return o, err
	}
	return o, json.Unmarshal(raw, &o.Items)
}

// Insert saves a new order with status "new".
func (p *PGStore) Insert(ctx context.Context, items []Item) (Order, error) {
	raw, err := json.Marshal(items)
	if err != nil {
		return Order{}, err
	}
	return scanOrder(p.pool.QueryRow(ctx,
		`INSERT INTO orders (items) VALUES ($1::jsonb)
		 RETURNING id, items, status, created_at`, string(raw)))
}

// Get returns one order or errNotFound.
func (p *PGStore) Get(ctx context.Context, id int) (Order, error) {
	o, err := scanOrder(p.pool.QueryRow(ctx,
		`SELECT id, items, status, created_at FROM orders WHERE id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return Order{}, errNotFound
	}
	return o, err
}

// List returns the newest orders first.
func (p *PGStore) List(ctx context.Context, limit int) ([]Order, error) {
	rows, err := p.pool.Query(ctx,
		`SELECT id, items, status, created_at FROM orders ORDER BY id DESC LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	orders := make([]Order, 0)
	for rows.Next() {
		o, err := scanOrder(rows)
		if err != nil {
			return nil, err
		}
		orders = append(orders, o)
	}
	return orders, rows.Err()
}

// RedisQueue puts jobs on the kitchen queue and updates the stats keys.
type RedisQueue struct {
	rdb *redis.Client
}

// Enqueue pushes the order id on orders:queue and updates stats in one transaction.
func (q *RedisQueue) Enqueue(ctx context.Context, o Order) error {
	minuteKey := fmt.Sprintf("stats:orders:%d", time.Now().Unix()/60)
	pipe := q.rdb.TxPipeline()
	pipe.LPush(ctx, "orders:queue", strconv.Itoa(o.ID))
	pipe.Incr(ctx, minuteKey)
	pipe.Expire(ctx, minuteKey, time.Hour)
	for _, it := range o.Items {
		pipe.ZIncrBy(ctx, "stats:dishes", float64(it.Qty), it.Name)
	}
	_, err := pipe.Exec(ctx)
	return err
}
