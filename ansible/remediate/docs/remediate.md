# Remediate Function

## Purpose

The `remediate/` function contains corrective automation intended to undo or fix workshop-induced drift or failure states.

Execution guidance:

- Current remediation content is AAP-oriented because the existing playbook has a matching controller job template and pairs directly with the automate drift scenario.

## Playbooks

### `remediate/playbooks/configure_app_ai_openfeature.yml`

Purpose:

- Reset the embedding model back to the desired value through the application API.

Execution mode:

- Intended for AAP.
- Evidence: matching remediation job template exists in `deploy/roles/aap_config/defaults/main.yml`.

Role used:

- `app_ai_openfeature`

What the role does:

- Calls the embedding-model API endpoint.
- Asserts the remediation succeeded.
- Prints previous and current model values.

Workshop relationship:

- This is the corrective counterpart to `automate/playbooks/configure_app_ai_openfeature.yml`.

## Roles

### `remediate/roles/app_ai_openfeature`

- Used by `configure_app_ai_openfeature.yml`.
- Focused remediation role for embedding-model drift.
- Best executed through AAP as part of the workshop’s controller or EDA remediation path.

## AAP vs Plain Ansible Summary

Prefer AAP:

- `configure_app_ai_openfeature.yml`
