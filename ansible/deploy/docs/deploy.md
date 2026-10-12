# Deploy Function

## Purpose

The `deploy/` function covers application build and release, Dynatrace-related deployment helpers, and Automation Platform bootstrap for the workshop. This function is mixed: some playbooks are normal controller job-template targets, while others are bootstrap or administration playbooks run directly with plain Ansible.

## Playbooks

### Application build and deploy

#### `deploy/playbooks/build_images.yml`

- Purpose: build the workshop application image.
- Role: `podman_build`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/deploy_app.yml`

- Purpose: deploy the full application stack and verify health.
- Role: `podman_deploy`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/site.yml`

- Purpose: wrapper that imports `build_images.yml` and `deploy_app.yml`.
- Execution mode: plain Ansible.
- Reason: no dedicated job template is defined for the wrapper playbook itself.

#### `deploy/playbooks/test_node_readiness.yml`

- Purpose: validate target node OS, Podman presence, and sudo behavior.
- Execution mode: intended for AAP.
- Evidence: matching validation job template exists.

### Dynatrace deployment playbooks

#### `deploy/playbooks/deploy_dynatrace_oneagent.yml`

- Purpose: install Dynatrace OneAgent on target hosts.
- Role: `dynatrace_oneagent_deploy`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/deploy_dynatrace_monaco.yml`

- Purpose: deploy Monaco configuration into Dynatrace.
- Role: `dynatrace_monaco_config`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/deploy_dynatrace_apps.yml`

- Purpose: install Dynatrace AppEngine apps via the App Registry API.
- Role: `dynatrace_app_registry`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/deploy_dynatrace_api_config.yml`

- Purpose: manage Dynatrace Settings API configuration, including EDA webhook connection details.
- Role: `dynatrace_api_config`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

#### `deploy/playbooks/deploy_dynatrace_edgeconnect.yml`

- Purpose: register and run Dynatrace EdgeConnect as a Podman container.
- Role: `dynatrace_edgeconnect_deploy`
- Execution mode: intended for AAP.
- Evidence: matching AAP job template exists.

### AAP bootstrap and administration playbooks

#### `deploy/playbooks/configure_aap.yml`

- Purpose: create core Automation Controller workshop objects.
- Role: `aap_config`
- Execution mode: plain Ansible.
- Reason: this is the bootstrap playbook that creates controller users, teams, credentials, inventories, projects, and job templates used by the rest of the workshop.

#### `deploy/playbooks/configure_eda.yml`

- Purpose: register EDA objects, project sync, decision environment, and rulebook activation.
- Role: `aap_config` using `tasks_from: eda_objects.yml`
- Execution mode: plain Ansible.
- Reason: this is controller/bootstrap administration, not a workshop job-template target.

#### `deploy/playbooks/update_ee.yml`

- Purpose: update the custom execution environment image reference in AAP.
- Execution mode: plain Ansible.
- Reason: administrative helper for controller configuration; no matching job template exists.

#### `deploy/playbooks/sync_runtime_base_dir.yml`

- Purpose: sync workshop runtime content from the repository working tree to the service-account runtime directory.
- Role: `aap_config` using `tasks_from: sync_runtime_base_dir.yml`
- Execution mode: plain Ansible.
- Reason: operational helper to refresh runtime content (for example, app updates) without running the full AAP bootstrap flow.

## Roles

### `deploy/roles/podman_build`

- Used by `build_images.yml`.
- Verifies Podman, resolves the Containerfile, builds the image, and confirms the result.
- Core AAP-targeted build role.

### `deploy/roles/podman_deploy`

- Used by `deploy_app.yml`.
- Creates the Podman network and orchestrates Weaviate, Ollama, OpenTelemetry Collector, travel-advisor, and Nginx.
- Handles AI runtime environment assembly, health checks, and startup sequencing.
- Renders the OpenTelemetry Collector config from `templates/otel-collector-config.yaml.j2` when Dynatrace or Arize AX export is enabled (otherwise the static `app/opentelemetry/otel-collector-config.yaml`, debug exporter only, is used).

#### Telemetry export modes

The app always sends its OpenTelemetry traces and metrics to the Collector. What reaches Dynatrace depends on whether OneAgent is deployed:

| Mode | OneAgent | `otel_collector_dynatrace_export_traces` | Spans reach Dynatrace via | OpenPipeline spans route |
|---|---|---|---|---|
| OneAgent (default) | deployed | `false` | OneAgent (captures the app's OpenTelemetry spans) | `dt.host_group.id == "destination-automation"` → `destination-automation-spans` |
| OpenTelemetry only | **not** deployed | `true` | Collector OTLP export | `service.namespace == "destination-automation"` → `destination-automation-otlp-spans` |

Only set `otel_collector_dynatrace_export_traces: true` when OneAgent is not deployed; otherwise every span arrives twice. Both spans pipelines apply the same OpenInference to `gen_ai.*` normalization, metrics, and bizevents.

Collector variables (role defaults in `deploy/roles/podman_deploy/defaults/main.yml`; deploy-app job template extra vars in `deploy/roles/aap_config/defaults/main.yml`):

| Variable | Default | Purpose |
|---|---|---|
| `otel_collector_dynatrace_export` | `false` (job template: `true`) | Enable the `otlphttp/dynatrace` exporter (`DT_OTLP_ENDPOINT`, `DT_OTLP_TOKEN` from the Dynatrace OTLP credential, `Api-Token` header) |
| `otel_collector_dynatrace_export_traces` / `_metrics` / `_logs` | `true` (job template: `false` / `true` / `false`) | Per-signal Dynatrace export switches |
| `otel_collector_service_namespace` | `destination-automation` | `service.namespace` resource attribute added to all OTLP telemetry; used by the OTLP spans and bizevents routes |
| `otel_collector_arize_export` | `false` | Enable the `otlp/arize` traces exporter, independent of the Dynatrace export (works with or without OneAgent) |
| `otel_collector_arize_endpoint` | `otlp.arize.com:443` | Arize AX OTLP gRPC endpoint |
| `otel_collector_arize_space_id` / `otel_collector_arize_api_key` | `ARIZE_SPACE_ID` / `ARIZE_API_KEY` env | Injected by the Arize AX credential; the Arize project comes from the app's `openinference.project.name` resource attribute |

### `deploy/roles/dynatrace_oneagent_deploy`

- Used by `deploy_dynatrace_oneagent.yml`.
- Validates OneAgent configuration, resolves version mode, and delegates installation through the Dynatrace collection.
- Accepts injected environment variables from the Dynatrace OneAgent PaaS Token credential type: `oneagent_environment_url` and `oneagent_paas_token`.
- Maintains backward compatibility with legacy environment variables: `DYNATRACE_ENV_URL` and `DYNATRACE_PAAS_TOKEN`.

### `deploy/roles/dynatrace_monaco_config`

- Used by `deploy_dynatrace_monaco.yml`.
- Validates Monaco credentials, ensures a pinned binary exists, performs dry-run validation, and deploys the Monaco project.

### `deploy/roles/dynatrace_app_registry`

- Used by `deploy_dynatrace_apps.yml`.
- Validates platform credentials and installs a configured list of Dynatrace AppEngine apps.

### `deploy/roles/dynatrace_api_config`

- Used by `deploy_dynatrace_api_config.yml`.
- Manages Dynatrace Settings API state for outbound connection allowlists and EDA webhook connection settings.
- Implements Settings API endpoint resolution with preferred-then-fallback logic:
  - Prefers the platform tenant path: `/platform/classic/environment-api/v2/settings/objects`
  - Falls back to legacy path: `/api/v2/settings/objects` if the preferred endpoint fails
  - This ensures compatibility across both SaaS and managed Dynatrace tenant variants
- Corrects EDA webhook credential type to `api-token` (schema-compliant value).

### `deploy/roles/dynatrace_edgeconnect_deploy`

- Used by `deploy_dynatrace_edgeconnect.yml`.
- Obtains OAuth credentials, registers the EdgeConnect configuration, renders config files, and runs the EdgeConnect container.

### `deploy/roles/aap_config`

- Used by `configure_aap.yml`, `configure_eda.yml`, and `sync_runtime_base_dir.yml`.
- This is the controller bootstrap role for the workshop.
- Major responsibilities:
  - validate controller and deployment settings
  - create custom credential types for Dynatrace integrations (Monaco Platform Token, OTLP Token, OAuth Client, OneAgent PaaS Token) and for the optional Arize AX export (Arize AX: space ID and API key)
  - create placeholder credentials for each custom credential type
  - copy project content into AAP-local paths for local mode
  - create controller logins, including instructor, participant users, and the EDA service account
  - generate platform API tokens for all users via Gateway API:
    - instructor token with `write` scope for full platform access
    - participant tokens with `read` scope for observability access
    - tokens stored in the password store directory for MCP server integration
  - create teams, credentials, project, inventory, organizations, and role assignments
  - register job templates for deploy, clean, operate, automate, and remediate playbooks
  - attach appropriate custom credentials to each job template (e.g., OneAgent job template receives both machine and OneAgent PaaS Token credentials)
  - configure EDA project, DE, controller credential, and rulebook activation
  - provide a sync-only task path (`tasks_from: sync_runtime_base_dir.yml`) to refresh `/app` and `/dynatrace/config` into `/home/aap-service-account/destination-automation`

## AAP vs Plain Ansible Summary

Prefer AAP:

- `build_images.yml`
- `deploy_app.yml`
- `test_node_readiness.yml`
- `deploy_dynatrace_oneagent.yml`
- `deploy_dynatrace_monaco.yml`
- `deploy_dynatrace_apps.yml`
- `deploy_dynatrace_api_config.yml`
- `deploy_dynatrace_edgeconnect.yml`

Prefer plain `ansible-playbook`:

- `site.yml`
- `configure_aap.yml`
- `configure_eda.yml`
- `update_ee.yml`
- `sync_runtime_base_dir.yml`
