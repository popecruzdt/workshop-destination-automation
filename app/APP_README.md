# AI Travel Advisor Application

The easyTravel AI Travel Advisor app is a local-first FastAPI application that answers travel questions with Ollama and Weaviate. It serves a browser UI, exposes API endpoints for direct and retrieval-augmented responses, indexes destination HTML files into a vector store, and includes optional OpenTelemetry instrumentation for workshop observability scenarios.

This file is the source of truth for what the app does, how it is structured, and which runtime controls are currently supported.

## What the App Is

The application combines three pieces:

1. A FastAPI web server in `src/main.py` that serves the UI and API.
2. A retrieval pipeline in `src/rag/__init__.py` that loads destination HTML files, chunks them, creates embeddings through Ollama, and stores them in Weaviate.
3. A static front end in `public/index.html` that lets users switch between response modes and query the app interactively.

The app supports three response modes through `/api/v1/completion`:

- `rag`: recommended mode; retrieves indexed destination content and uses it as context.
- `llm`: direct model call without retrieval context.
- `agentic`: currently implemented as a fallback to the direct `llm` path.

## Runtime Architecture

At runtime the app is usually deployed with four services:

- `travel-advisor`: the FastAPI application container.
- `ollama`: local model runtime for chat and embeddings.
- `weaviate`: vector database used for the knowledge base.
- `nginx`: reverse proxy that publishes the UI in the compose flow.

An optional `otel-collector` service is also defined for OpenTelemetry export during observability demos.

High-level request flow:

1. The browser loads `/` from FastAPI directly or through Nginx.
2. The UI calls `/api/v1/completion?framework=...&prompt=...`.
3. In `llm` mode, the app sends the prompt directly to Ollama.
4. In `rag` mode, the app queries Weaviate for relevant destination chunks, builds a prompt from the retrieved context plus `prompts/rag_instructions.txt`, and then calls Ollama.
5. The response is returned as JSON and rendered in the UI.

Startup behavior matters:

- The app prepares the RAG knowledge base during FastAPI startup.
- It retries Weaviate initialization until the database is ready.
- If the knowledge base already has at least `MIN_KB_OBJECTS` objects and `FORCE_REINDEX` is not enabled, reindexing is skipped.

## Code Layout

Key files and directories:

- `src/main.py`: FastAPI app, startup lifecycle, API endpoints, and OpenTelemetry initialization.
- `src/config.py`: environment-backed settings loaded from `.env` and the process environment.
- `src/rag/__init__.py`: knowledge-base preparation, retrieval logic, prompt loading, and embedding drift simulation.
- `src/feature_flags.py`: in-memory OpenFeature flag used to override the embedding model at runtime.
- `src/telemetry/`: custom Ollama span instrumentation.
- `src/utils/__init__.py`: logging configuration and API response formatting.
- `public/index.html`: browser UI.
- `destinations/`: HTML source documents for the RAG knowledge base.
- `prompts/rag_instructions.txt`: prompt template used for RAG answers.
- `nginx/default.conf`: reverse proxy for the compose deployment.
- `Containerfile`: application image build.
- `podman-compose.yml`: local multi-container runtime definition.
- `opentelemetry/otel-collector-config.yaml`: collector config used by the optional compose collector.

## How It Works

### API surface

Primary endpoints:

- `GET /health`: liveness summary plus Ollama and Weaviate connectivity state.
- `GET /api/v1/status`: current model and retrieval settings.
- `GET /api/v1/completion`: response generation entry point.
- `GET /api/v1/prepare-kb`: rebuild the knowledge base from `destinations/`.
- `GET /api/v1/set-embedding-model`: set an in-memory embedding override used for drift simulation.
- `GET /api/v1/thumbsUp` and `GET /api/v1/thumbsDown`: lightweight feedback logging endpoints.

### Retrieval pipeline

The RAG flow in `src/rag/__init__.py` works like this:

1. Load every `*.html` file from `DESTINATIONS_PATH`.
2. Parse them with `BSHTMLLoader`.
3. Split content into chunks using `CHUNK_SIZE` and `CHUNK_OVERLAP`.
4. Create vectors in Weaviate using the Ollama embedding model named by `AI_EMBEDDING_MODEL`.
5. For a user query, try exact lexical retrieval first and then vector retrieval.
6. Build the final prompt from the retrieved text plus `RAG_PROMPT_PATH`.
7. Send that prompt to the chat model named by `AI_MODEL`.

If no useful context is found, the app returns a constrained fallback response instead of hallucinating details.

### Prompt control

The RAG response instructions are file-driven. The app loads `prompts/rag_instructions.txt` at runtime when the file exists, otherwise it falls back to an internal prompt string in `src/rag/__init__.py`.

That means you can change response behavior without editing Python code by updating:

- `prompts/rag_instructions.txt`
- the destination HTML files in `destinations/`

After changing destination files, rebuild the knowledge base with `/api/v1/prepare-kb` or restart the app with `FORCE_REINDEX=true`.

## Runtime Control Surfaces

The app can be controlled in three main ways.

### 1. Environment variables

Settings are loaded from `.env` and the process environment. In containerized runs, service-level environment variables from `podman-compose.yml` override the image-baked `.env` file.

Important environment variables currently used by the app:

Core server:

- `SERVICE_NAME`
- `APP_VERSION`
- `ENVIRONMENT`
- `DEBUG`
- `HOST`
- `PORT`
- `LOG_LEVEL`

Ollama:

- `OLLAMA_ENDPOINT`
- `AI_MODEL`
- `AI_EMBEDDING_MODEL`
- `AI_TEMPERATURE`

Weaviate:

- `WEAVIATE_ENDPOINT`
- `WEAVIATE_PORT`
- `WEAVIATE_SCHEME`

RAG behavior:

- `MAX_PROMPT_LENGTH`
- `CHUNK_SIZE`
- `CHUNK_OVERLAP`
- `RETRIEVAL_K`
- `FORCE_REINDEX`
- `MIN_KB_OBJECTS`

Filesystem paths:

- `DESTINATIONS_PATH`
- `PUBLIC_PATH`
- `RAG_PROMPT_PATH`

OpenTelemetry and tracing:

- `OPENLLMETRY_ENABLED`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`
- `OTEL_SERVICE_NAME`
- `TRACELOOP_TRACE_CONTENT`

Note on legacy config values:

- `src/config.py` still defines some older telemetry-related settings such as `OTEL_ENABLED`, `OTEL_ENDPOINT`, `DYNATRACE_API_URL`, `DYNATRACE_API_TOKEN`, `API_TOKEN`, and `TRACELOOP_TELEMETRY`, but the current runtime instrumentation path is controlled by `OPENLLMETRY_ENABLED` and the `OTEL_EXPORTER_OTLP_*` variables above.

### 2. Runtime-managed files

These files directly change app behavior without code edits:

- `destinations/*.html`: the knowledge base source documents.
- `prompts/rag_instructions.txt`: the retrieval prompt template.
- `public/index.html`: the browser UI.
- `nginx/default.conf`: external routing for the compose deployment.
- `opentelemetry/otel-collector-config.yaml`: collector export behavior in the compose deployment.

### 3. Control APIs

These endpoints change or refresh behavior at runtime:

- `/api/v1/prepare-kb`: rebuild indexed destination content.
- `/api/v1/set-embedding-model?model=...`: change the active embedding override in memory for drift simulation.

The embedding override is implemented with an in-process OpenFeature provider in `src/feature_flags.py`. It is not persisted across restarts.

## Local Run Modes

### Manual Python run

Use this when developing the app directly on the host:

```bash
cd /home/ec2-user/workshop-destination-automation/app
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python -m src.main
```

Manual runs typically expose the app on `http://localhost:8082` because `.env.example` sets `PORT=8082`.

### Podman Compose run

Use this when you want the full containerized stack defined in `podman-compose.yml`.

See `PODMAN_COMPOSE_SETUP.md` for the complete procedure.

Important compose-specific details:

- The app container listens on port `8080` internally.
- Nginx publishes the stack externally on `http://localhost:81`.
- The compose file mounts `src/`, `public/`, `prompts/`, and `destinations/` from the host into the app container.
- Changes to Python code and content files are visible inside the container immediately, but you still need to restart the app container for Python process changes to take effect because `DEBUG` is disabled in compose.

## Container Build Notes

The `Containerfile` builds a self-contained Python 3.13 image that:

- installs the Python dependencies from `requirements.txt`
- copies `src/`, `public/`, and `prompts/`
- copies `.env.example` to `.env` as the image default
- creates `/app/destinations`
- runs the process as a non-root user

Because the image bakes in `.env.example`, compose environment variables and bind mounts become the main override layers when running locally with Podman Compose.

## Common Operations

Query the app directly:

```bash
curl "http://localhost:8082/api/v1/completion?framework=rag&prompt=Paris"
curl "http://localhost:8082/api/v1/completion?framework=llm&prompt=Tokyo"
curl "http://localhost:8082/api/v1/completion?framework=agentic&prompt=Sydney"
```

Rebuild the knowledge base:

```bash
curl http://localhost:8082/api/v1/prepare-kb
```

Check health:

```bash
curl http://localhost:8082/health
curl http://localhost:8082/api/v1/status
```

When using the compose deployment through Nginx, replace `:8082` with `:81`.

## Troubleshooting

Common causes of startup or response issues:

- Ollama is up but the required models are not pulled.
- Weaviate is running but not yet ready when the app starts.
- `FORCE_REINDEX=true` triggers a full rebuild and makes startup slower.
- Destination HTML files changed but the KB was not rebuilt.
- The compose stack was started without the `travel-advisor` image being built first.

Useful checks:

```bash
curl http://localhost:8082/health
curl http://localhost:8082/api/v1/status
podman logs travel-advisor
podman logs ollama
podman logs weaviate
```

## Related Files

- `PODMAN_COMPOSE_SETUP.md`: step-by-step compose setup and lifecycle commands.
- `.env.example`: current example environment file for manual host-based runs.
