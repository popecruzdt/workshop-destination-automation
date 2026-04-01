# AI Travel Advisor Podman Compose Setup

This guide documents the manual containerized workflow for running the easyTravel AI Travel Advisor application with `podman-compose`.

It assumes you want the full local stack defined in `podman-compose.yml`:

- `weaviate`
- `ollama`
- `otel-collector`
- `travel-advisor`
- `nginx`

The compose deployment publishes the application through Nginx on `http://localhost:81`.

## What You Need

Install these prerequisites first:

1. Podman
2. `podman-compose`
3. Network access to pull the base images and Ollama models

Typical install options on Linux:

```bash
sudo dnf install -y podman
python3 -m pip install --user podman-compose
```

Verify the tools are available:

```bash
podman --version
podman-compose --version
```

## Files Used By This Flow

The compose deployment depends on these files in this directory:

- `Containerfile`
- `podman-compose.yml`
- `nginx/default.conf`
- `opentelemetry/otel-collector-config.yaml`
- `src/`
- `public/`
- `prompts/`
- `destinations/`

The app image copies `.env.example` into the image as `.env`, but the compose file overrides the most important runtime values explicitly for the containerized deployment.

## Step 1: Move Into The App Directory

```bash
cd /home/ec2-user/workshop-destination-automation/app
```

## Step 2: Build The Application Image

Build the local app image before starting the `travel-advisor` service:

```bash
podman build -f Containerfile -t localhost/ai-travel-advisor:latest .
```

Rebuild the image when one of these changes:

- `requirements.txt`
- `Containerfile`
- files copied into the image during build that are not also bind-mounted at runtime

You do not need to rebuild just to change `src/`, `public/`, `prompts/`, or `destinations/` because those paths are bind-mounted by `podman-compose.yml`.

## Step 3: Start Dependencies First

Bring up Weaviate, Ollama, and the optional OTEL collector before starting the app:

```bash
podman-compose up -d weaviate ollama otel-collector
```

Check their state:

```bash
podman ps
podman logs weaviate
podman logs ollama
podman logs otel-collector
```

## Step 4: Pull The Required Ollama Models

The compose stack expects these models:

- chat model: `gemma2:2b`
- embedding model: `nomic-embed-text`

Pull them into the running Ollama container:

```bash
podman exec ollama ollama pull gemma2:2b
podman exec ollama ollama pull nomic-embed-text
```

Confirm they are present:

```bash
podman exec ollama ollama list
```

## Step 5: Start The Application And Proxy

Start the FastAPI application container and Nginx:

```bash
podman-compose up -d travel-advisor nginx
```

Check startup logs:

```bash
podman logs travel-advisor
podman logs travel-advisor-nginx
```

Important startup note:

- The app prepares the knowledge base during startup.
- On a fresh run, startup can take a while because the destination HTML files are parsed, chunked, embedded, and indexed into Weaviate.
- If the knowledge base already exists and `FORCE_REINDEX=false`, startup is faster because reindexing is skipped.

## Step 6: Verify The Stack

Open the UI:

```text
http://localhost:81
```

Verify health through Nginx:

```bash
curl http://localhost:81/health
curl http://localhost:81/api/v1/status
```

Run a sample query:

```bash
curl "http://localhost:81/api/v1/completion?framework=rag&prompt=Paris"
```

## Step 7: Update Content Or Prompting

You can change behavior without rebuilding the image by editing bind-mounted files on the host:

- `destinations/*.html`
- `prompts/rag_instructions.txt`
- `public/index.html`
- `src/*.py`

What to do after changes:

- destination content changes: rebuild the KB with `GET /api/v1/prepare-kb` or restart the app with `FORCE_REINDEX=true`
- prompt template changes: restart `travel-advisor`
- Python code changes: restart `travel-advisor`
- static UI changes: reload the browser; restart only if the server behavior changed too

Rebuild the knowledge base after destination edits:

```bash
curl http://localhost:81/api/v1/prepare-kb
```

Restart just the application container:

```bash
podman restart travel-advisor
```

## Step 8: Stop Or Remove The Stack

Stop the services but keep containers and volumes:

```bash
podman-compose stop
```

Remove the containers but keep named volumes:

```bash
podman-compose down
```

Remove the containers and the named volumes used for Ollama and Weaviate data:

```bash
podman-compose down -v
```

## Runtime Configuration Used By Compose

The `travel-advisor` service sets these runtime values directly in `podman-compose.yml`:

- `OLLAMA_ENDPOINT=http://ollama:11434`
- `WEAVIATE_ENDPOINT=weaviate`
- `WEAVIATE_PORT=8080`
- `AI_MODEL=gemma2:2b`
- `AI_EMBEDDING_MODEL=nomic-embed-text`
- `AI_TEMPERATURE=0.7`
- `HOST=travel-advisor`
- `PORT=8080`
- `DEBUG=false`
- `FORCE_REINDEX=false`
- `CHUNK_SIZE=500`
- `CHUNK_OVERLAP=0`
- `RETRIEVAL_K=10`
- `MIN_KB_OBJECTS=450`
- `OPENLLMETRY_ENABLED=true`
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317`
- `OTEL_SERVICE_NAME=ai-travel-advisor`
- `TRACELOOP_TRACE_CONTENT=true`

That means compose behavior differs from a plain host-based run in two notable ways:

1. The app is exposed externally through Nginx on port `81`, not directly on `8082`.
2. Compose enables tracing and uses a larger retrieval fan-out than the example `.env` file used for manual runs.

## Troubleshooting

If the app does not come up cleanly, check these issues first.

### Ollama is up but responses fail

Cause:

- required model images were not pulled into the Ollama container

Fix:

```bash
podman exec ollama ollama list
podman exec ollama ollama pull gemma2:2b
podman exec ollama ollama pull nomic-embed-text
```

### The app keeps restarting or fails during startup

Cause:

- Weaviate was not ready when the app attempted KB preparation

Fix:

```bash
podman logs weaviate
podman logs travel-advisor
podman restart travel-advisor
```

### Destination changes do not show up in RAG responses

Cause:

- the existing KB was reused

Fix:

```bash
curl http://localhost:81/api/v1/prepare-kb
```

Or temporarily set `FORCE_REINDEX=true` in `podman-compose.yml` and restart `travel-advisor`.

### Python code changes are not taking effect

Cause:

- the container bind mount updated the files, but the Python process was not restarted

Fix:

```bash
podman restart travel-advisor
```

### You changed dependencies and the app still fails

Cause:

- the app image was not rebuilt after modifying `requirements.txt`

Fix:

```bash
podman build -f Containerfile -t localhost/ai-travel-advisor:latest .
podman-compose up -d travel-advisor nginx
```