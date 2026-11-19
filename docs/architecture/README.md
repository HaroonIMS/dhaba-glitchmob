# Dhaba GlitchMob — System Architecture

## Overview

Dhaba GlitchMob is a containerized application deployed on an AWS EC2 instance using K3s Kubernetes. The project uses separate Kubernetes namespaces for staging and production to maintain environment isolation.

Infrastructure monitoring is implemented using Prometheus, Node Exporter, and Grafana.

## Application Infrastructure

- **GitHub:** Source code and Kubernetes deployment configurations.
- **AWS ECR:** Stores versioned Docker images.
- **AWS EC2:** Hosts the K3s Kubernetes cluster.
- **K3s:** Lightweight Kubernetes distribution managing application workloads.
- **Staging:** Environment for testing application changes before production.
- **Production:** Separate environment for the production application.

## Monitoring Architecture

- **Node Exporter:** Runs on EC2 and exposes Linux system metrics on `127.0.0.1:9100`.
- **SSH Tunnel:** Securely forwards the Node Exporter metrics endpoint to the local laptop.
- **Prometheus:** Runs locally on port `9090` and collects infrastructure metrics.
- **Grafana:** Runs locally on port `3000` and visualizes metrics through an interactive monitoring dashboard.

## Security Considerations

- Node Exporter listens only on the EC2 loopback interface.
- Port `9100` is not exposed publicly.
- SSH tunneling provides secure access to EC2 monitoring metrics.
- Staging and production workloads are maintained in separate Kubernetes namespaces.

## Monitoring Dashboard

The Grafana dashboard provides visibility into:

- CPU utilization
- Memory utilization
- Disk usage
- Network traffic
- System load
- Operating system and system-level metrics

See the [Grafana monitoring screenshot](../screenshots/grafana-ec2-monitoring.png).

## Architecture Diagram

See [architecture.mmd](architecture.mmd) for the Mermaid architecture diagram.
