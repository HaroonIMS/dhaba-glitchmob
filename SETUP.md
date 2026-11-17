# Dhaba Orders: services (Amir)

One-time steps after unzipping (needs network):

    cd orders-api && go mod tidy            # creates go.sum, commit it
    cd stats-api  && ./setup.sh             # adds the Laravel skeleton + composer.lock, commit them
    # web/package-lock.json is already included

Local checks (same commands as CI):

    web:            npm ci && npx eslint . && npx vitest run
    menu-api:       pip install -r requirements-dev.txt && ruff check . && pytest
    orders-api:     golangci-lint run && go test ./...
    kitchen-worker: mvn checkstyle:check && mvn test
    stats-api:      vendor/bin/phpstan analyse && vendor/bin/phpunit

Whole system locally:

    export POSTGRES_PASSWORD='something-local'
    cd dev && docker compose up --build        # http://localhost:8088

Contract for teammates:
  ports       web 8080, menu-api 8000, orders-api 8080, stats-api 8080 (kitchen-worker: none)
  probes      GET /health on every web service; kitchen-worker health = file /tmp/heartbeat (Docker only)
  version     GET /info and GET /api/<menu|orders|stats>/info -> {"version","pod"}; web: GET /info
  env vars    POSTGRES_HOST POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD REDIS_HOST GIT_COMMIT
  schema      db/init.sql (mount into /docker-entrypoint-initdb.d/)
  note        orders-api waits 5s on SIGTERM before shutting down (use terminationGracePeriodSeconds >= 30)
