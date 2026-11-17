import json

import psycopg
from fastapi.testclient import TestClient

from app import main

client = TestClient(main.app)
MENU = [{"id": 1, "name": "Biryani", "price": 9.0}]


class FakeRedis:
    def __init__(self, cached=None):
        self.cached = cached
        self.stored = None

    def get(self, key):
        return self.cached

    def setex(self, key, ttl, value):
        self.stored = (key, ttl, value)


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_info_shows_version_and_pod(monkeypatch):
    monkeypatch.setattr(main, "VERSION", "abc123")
    body = client.get("/api/menu/info").json()
    assert body["version"] == "abc123"
    assert body["pod"]


def test_menu_is_loaded_from_db_and_cached(monkeypatch):
    fake = FakeRedis()
    monkeypatch.setattr(main, "get_redis", lambda: fake)
    monkeypatch.setattr(main, "load_menu_from_db", lambda: MENU)

    assert client.get("/api/menu").json() == MENU
    assert fake.stored[0] == "menu:cache"
    assert fake.stored[1] == 60


def test_menu_comes_from_cache_without_touching_db(monkeypatch):
    monkeypatch.setattr(main, "get_redis", lambda: FakeRedis(cached=json.dumps(MENU)))

    def boom():
        raise AssertionError("database must not be used on a cache hit")

    monkeypatch.setattr(main, "load_menu_from_db", boom)
    assert client.get("/api/menu").json() == MENU


def test_menu_returns_503_when_database_is_down(monkeypatch):
    monkeypatch.setattr(main, "get_redis", lambda: FakeRedis())

    def down():
        raise psycopg.OperationalError("down")

    monkeypatch.setattr(main, "load_menu_from_db", down)
    assert client.get("/api/menu").status_code == 503
