# Stage 1: download a pinned kubectl
FROM debian:bookworm-slim AS tools

ARG KUBECTL_VERSION=v1.37.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod +x /usr/local/bin/kubectl

# Stage 2: runtime image
FROM debian:bookworm-slim

ARG VERSION=unknown

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash curl ca-certificates postgresql-client redis-tools jq \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system ops \
 && useradd --system --gid ops --home-dir /home/ops --create-home ops

COPY --from=tools /usr/local/bin/kubectl /usr/local/bin/kubectl
COPY scripts/monitor/ /opt/monitor/

RUN chmod +x /opt/monitor/*.sh

ENV VERSION=${VERSION}

WORKDIR /opt/monitor

USER ops

CMD ["/opt/monitor/check-cluster.sh"]
