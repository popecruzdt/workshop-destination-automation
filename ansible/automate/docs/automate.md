# Automate Function

## Purpose

The `automate/` function contains workshop automations that intentionally change application or platform behavior. These are the automation scenarios used to demonstrate controlled change, configuration drift, and observability outcomes.

Execution guidance:

- Prefer AAP for playbooks that already have matching job templates in the `aap_config` role.
- Use plain `ansible-playbook` for local development, ad hoc testing, or for playbooks that do not currently have an AAP job template.

## Playbooks

### `automate/playbooks/configure_app_ai_runtime.yml`

Purpose:

- Updates runtime-facing AI settings by editing deploy inventory values and prompt content.
- Supports AI model changes, temperature changes, and RAG instruction updates.

Execution mode:

- Intended for AAP.
- Evidence: this playbook is bound to multiple AAP job templates in `deploy/roles/aap_config/defaults/main.yml` for model, temperature, and RAG instruction changes.

Role used:

- `app_ai_runtime_config`

What the role does:

- Validates requested model and temperature values.
- Resolves and updates the deploy inventory `group_vars/all.yml` file.
- Updates the RAG instructions file.
- Verifies the requested values were actually written.

Operational note:

- This playbook changes files that affect future or recycled deployments; it does not directly restart the running app. Use the operate recycle flow afterward when needed.

### `automate/playbooks/configure_app_ai_destinations.yml`

Purpose:

- Generates destination HTML files that feed the travel-advisor app’s RAG context.

Execution mode:

- Intended for AAP.
- Evidence: this playbook has a matching AAP job template in `deploy/roles/aap_config/defaults/main.yml`.

Role used:

- `app_ai_destinations`

What the role does:

- Validates the `travel_destinations` list input.
- Renders HTML destination files from a Jinja template.
- Forces reindexing by updating deploy vars.
- Reminds the operator to run the recycle flow so the app reloads the new content.

### `automate/playbooks/configure_app_ai_openfeature.yml`

Purpose:

- Simulates embedding-model drift by changing the app embedding model through the OpenFeature-facing API.

Execution mode:

- Intended for AAP.
- Evidence: this playbook has a matching AAP job template in `deploy/roles/aap_config/defaults/main.yml`.

Role used:

- `app_ai_openfeature`

What the role does:

- Validates the requested embedding model.
- Exits cleanly if no model change is requested.
- Calls the application API to change the embedding model.
- Prints before/after state returned by the app.

### `automate/playbooks/configure_dynatrace.yml`

Purpose:

- Configures Dynatrace monitoring primitives for the workshop app.

Execution mode:

- Plain Ansible.
- No matching AAP job template is currently defined for this playbook.

Role used:

- `dynatrace_configure`

What the role does:

- Validates Dynatrace API credentials.
- Checks API reachability.
- Creates or updates a management zone.
- Creates an HTTP synthetic monitor.
- Ingests a deployment metric.

## Roles

### `automate/roles/app_ai_runtime_config`

- Used by `configure_app_ai_runtime.yml`.
- File-editing role for AI runtime controls and RAG content.
- Best executed through AAP job templates because the workshop already models these changes as named controller jobs.

### `automate/roles/app_ai_destinations`

- Used by `configure_app_ai_destinations.yml`.
- Generates destination content files and sets `FORCE_REINDEX` to trigger knowledge-base refresh on recycle.
- Best executed through AAP so content changes are part of the workshop flow.

### `automate/roles/app_ai_openfeature`

- Used by `configure_app_ai_openfeature.yml`.
- Performs API-driven embedding-model drift simulation.
- Best executed through AAP because it has a matching remediation counterpart and a dedicated workshop job template.

### `automate/roles/dynatrace_configure`

- Used by `configure_dynatrace.yml`.
- Configures Dynatrace directly through API calls.
- Currently a plain-Ansible helper role rather than an AAP-bound workshop job.

## AAP vs Plain Ansible Summary

Prefer AAP:

- `configure_app_ai_runtime.yml`
- `configure_app_ai_destinations.yml`
- `configure_app_ai_openfeature.yml`

Prefer plain `ansible-playbook`:

- `configure_dynatrace.yml`
