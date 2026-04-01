# Workshop Guide: Dynatrace + Ansible Automation Platform + AI Workload

## Overview

This workshop demonstrates a production-style workflow using:

- **Red Hat Ansible Automation Platform (AAP)** — automated build, deploy, and lifecycle management
- **Dynatrace** — full-stack observability and AI-powered monitoring
- **AI Inference API** — a containerized AI workload (FastAPI + inference models)
- **Podman** — daemonless container runtime for building and running images

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Ansible Automation Platform                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │build_images  │  │ deploy_app   │  │configure_dynatrace │   │
│  │  .yml        │  │  .yml        │  │  .yml              │   │
│  └──────┬───────┘  └──────┬───────┘  └─────────┬──────────┘   │
│         │                 │                    │               │
│         ▼                 ▼                    ▼               │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │podman_build  │  │podman_deploy │  │dynatrace_configure │   │
│  │   role       │  │   role       │  │   role             │   │
│  └──────┬───────┘  └──────┬───────┘  └─────────┬──────────┘   │
└─────────┼─────────────────┼──────────────────── ┼─────────────┘
          │                 │                     │
          ▼                 ▼                     ▼
   ┌──────────────┐  ┌──────────────┐    ┌───────────────┐
   │  Podman      │  │  Container   │    │  Dynatrace    │
   │  Build       │  │  Runtime     │    │  Tenant       │
   └──────────────┘  └──────┬───────┘    └───────────────┘
                             │
                             ▼
                    ┌────────────────────┐
                    │  AI Inference API  │
                    │  :8080             │
                    │  /health           │
                    │  /metrics          │
                    │  /api/v1/predict   │
                    └────────────────────┘
```

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| RHEL / Rocky Linux | 9.x | Host OS |
| Podman | 4.x+ | `dnf install podman` |
| Python | 3.11+ | For app development |
| Ansible | 2.15+ | `dnf install ansible-core` |
| Ansible Automation Platform | 2.4+ | Optional - can use `ansible-playbook` directly |
| Dynatrace tenant | SaaS or Managed | For monitoring |

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/popecruzdt/dev-destination-automation.git
cd dev-destination-automation
```

### 2. Install Ansible collections

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
```

### 3. Build the container image

```bash
ansible-playbook playbooks/build_images.yml
```

### 4. Deploy the application

```bash
ansible-playbook playbooks/deploy_app.yml
```

### 5. Verify deployment

```bash
curl http://localhost:8080/health
curl http://localhost:8080/api/v1/models
curl -X POST http://localhost:8080/api/v1/predict \
  -H "Content-Type: application/json" \
  -d '{"model":"text-summarizer-v1","input_text":"Ansible automates IT tasks."}'
```

### 6. Configure Dynatrace monitoring (requires Dynatrace tenant)

```bash
ansible-playbook playbooks/configure_dynatrace.yml \
  -e "dynatrace_api_url=https://<env-id>.live.dynatrace.com" \
  -e "dynatrace_api_token=<your-api-token>"
```

### 7. Run the full site playbook

```bash
ansible-playbook playbooks/site.yml \
  -e "dynatrace_api_url=https://<env-id>.live.dynatrace.com" \
  -e "dynatrace_api_token=<your-api-token>"
```

---

## Application Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Health check (used by Ansible & Dynatrace synthetic monitor) |
| `/metrics` | GET | Prometheus metrics (scraped by Dynatrace) |
| `/api/v1/models` | GET | List available inference models |
| `/api/v1/models/{name}` | GET | Get model details |
| `/api/v1/predict` | POST | Run AI inference |
| `/api/v1/stats` | GET | Application statistics |
| `/docs` | GET | OpenAPI documentation (Swagger UI) |

---

## Ansible Playbooks

| Playbook | Description |
|---|---|
| `site.yml` | Full orchestration: build + deploy + configure monitoring |
| `build_images.yml` | Build the container image with Podman |
| `deploy_app.yml` | Deploy the container and verify health |
| `stop_app.yml` | Gracefully stop and remove the container |
| `configure_dynatrace.yml` | Set up Dynatrace monitoring resources |

### Useful variables (override with `-e`)

| Variable | Default | Description |
|---|---|---|
| `image_tag` | `1.0.0` | Container image tag |
| `host_port` | `8080` | Host port mapping |
| `app_environment` | `workshop` | Environment label |
| `dynatrace_api_url` | `""` | Dynatrace environment URL |
| `dynatrace_api_token` | `""` | Dynatrace API token |
| `remove_image` | `false` | Remove image when stopping |

---

## Ansible Automation Platform (AAP) Setup

To run these playbooks from AAP:

1. **Create a Project** pointing to this repository
2. **Create an Inventory** using `ansible/inventories/localhost/hosts.yml`
3. **Create Credentials**:
   - Machine credential (for localhost)
   - Custom credential type for Dynatrace (`DYNATRACE_API_URL`, `DYNATRACE_API_TOKEN`)
4. **Create Job Templates** for each playbook
5. **Create a Workflow** linking build → deploy → configure

---

## Dynatrace Integration

### Metrics Exposed

The app exposes Prometheus metrics at `/metrics`. Configure Dynatrace to scrape:

- `ai_inference_requests_total` — total requests by model and status
- `ai_inference_request_duration_seconds` — latency histogram
- `ai_inference_active_requests` — concurrent requests gauge
- `ai_inference_model_load_seconds` — model load time

### Custom Dashboard

Import the dashboard from `dynatrace/dashboards/ai-inference-dashboard.json` in your Dynatrace tenant:

1. Go to **Dashboards** → **Import dashboard**
2. Upload `dynatrace/dashboards/ai-inference-dashboard.json`

### API Token Permissions Required

| Permission | Purpose |
|---|---|
| `metrics.ingest` | Push custom metrics |
| `entities.write` | Tag monitored entities |
| `syntheticExecutions.write` | Create synthetic monitors |
| `ReadConfig` | Read configuration |
| `WriteConfig` | Create management zones |

---

## Stopping the Application

```bash
# Stop container only
ansible-playbook playbooks/stop_app.yml

# Stop container and remove image
ansible-playbook playbooks/stop_app.yml -e "remove_image=true"
```

---

## Project Structure

```
dev-destination-automation/
├── README.md                          # Project overview
├── app/                               # AI Inference API source code
│   ├── Containerfile                  # Podman/Docker build definition
│   ├── requirements.txt               # Python dependencies
│   └── src/
│       ├── main.py                    # FastAPI application entry point
│       ├── config.py                  # Configuration (env vars)
│       └── models.py                  # Pydantic request/response models
├── ansible/                           # Ansible project
│   ├── ansible.cfg                    # Ansible configuration
│   ├── requirements.yml               # Collection dependencies
│   ├── inventories/
│   │   └── localhost/
│   │       ├── hosts.yml              # Inventory
│   │       └── group_vars/all.yml     # Shared variables
│   ├── playbooks/
│   │   ├── site.yml                   # Full orchestration playbook
│   │   ├── build_images.yml           # Build container image
│   │   ├── deploy_app.yml             # Deploy container
│   │   ├── stop_app.yml               # Stop and remove container
│   │   └── configure_dynatrace.yml    # Dynatrace monitoring setup
│   └── roles/
│       ├── podman_build/              # Podman image build role
│       ├── podman_deploy/             # Podman container deploy role
│       └── dynatrace_configure/       # Dynatrace configuration role
├── dynatrace/
│   └── dashboards/
│       └── ai-inference-dashboard.json  # Dynatrace dashboard definition
└── docs/
    └── workshop-guide.md              # This guide
```
