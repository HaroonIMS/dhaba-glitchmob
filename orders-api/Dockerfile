FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG GIT_COMMIT=dev
RUN CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=${GIT_COMMIT}" -o /orders-api .

FROM alpine:3.20
RUN adduser -D -u 10001 app
COPY --from=build /orders-api /orders-api
ARG GIT_COMMIT=dev
ENV GIT_COMMIT=${GIT_COMMIT}
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/orders-api"]
