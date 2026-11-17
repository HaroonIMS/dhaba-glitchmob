"""menu-api: serves the restaurant menu from Postgres, cached in Redis."""

import json
import os
import socket

import psycopg
import redis
from fastapi import FastAPI, HTTPException

VERSION = os.getenv("GIT_COMMIT", "dev")
CACHE_KEY = "menu:cache"
CACHE_TTL_SECONDS = 60

app = FastAPI(title="menu-api")


def get_redis() -> redis.Redis:
    return redis.Redis(
        host=os.getenv("REDIS_HOST", "redis"),
        port=6379,
        decode_responses=True,
        socket_timeout=2,
        socket_connect_timeout=2,
    )


def load_menu_from_db() -> list[dict]:
    with psycopg.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        dbname=os.getenv("POSTGRES_DB", "dhaba"),
        user=os.getenv("POSTGRES_USER", "dhaba"),
        password=os.getenv("POSTGRES_PASSWORD", ""),
        connect_timeout=3,
    ) as conn:
        rows = conn.execute("SELECT id, name, price FROM menu ORDER BY id").fetchall()
    return [{"id": r[0], "name": r[1], "price": float(r[2])} for r in rows]


def get_menu() -> list[dict]:
    cache = get_redis()
    try:
        cached = cache.get(CACHE_KEY)
        if cached:
            return json.loads(cached)
    except redis.RedisError:
        pass  # a broken cache must never break the menu

    menu = load_menu_from_db()
    try:
        cache.setex(CACHE_KEY, CACHE_TTL_SECONDS, json.dumps(menu))
    except redis.RedisError:
        pass
    return menu


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/info")
@app.get("/api/menu/info")  # reachable through the ingress
def info() -> dict:
    return {"version": VERSION, "pod": socket.gethostname()}


@app.get("/api/menu")
def menu() -> list[dict]:
    try:
        return get_menu()
    except psycopg.Error as exc:
        raise HTTPException(status_code=503, detail="menu database unavailable") from exc
