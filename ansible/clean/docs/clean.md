# Clean Function

## Purpose

The `clean/` function removes deployed workshop resources. It is the teardown counterpart to the deploy function and is intended for predictable cleanup of containers, networks, and images.

Execution guidance:

- The individual cleanup playbooks have matching AAP job templates, so prefer AAP for workshop runs.
- The wrapper `site.yml` is a plain-Ansible orchestrator with no dedicated AAP job template.

## Playbooks

### `clean/playbooks/remove_app.yml`

Purpose:

- Stops and removes the deployed application containers and network.

Execution mode:

- Intended for AAP.
- Evidence: matching AAP job template exists in `deploy/roles/aap_config/defaults/main.yml`.

Role used:

- `podman_clean` with `podman_clean_action=remove_app`

### `clean/playbooks/remove_image.yml`

Purpose:

- Removes the locally built container image from Podman storage.

Execution mode:

- Intended for AAP.
- Evidence: matching AAP job template exists in `deploy/roles/aap_config/defaults/main.yml`.

Role used:

- `podman_clean` with `podman_clean_action=remove_image`

### `clean/playbooks/site.yml`

Purpose:

- Sequential wrapper that imports `remove_app.yml` and `remove_image.yml`.

Execution mode:

- Plain Ansible.
- No matching AAP job template is defined for the wrapper playbook itself.

## Roles

### `clean/roles/podman_clean`

Purpose:

- Dispatch role for workshop cleanup operations.

What it does:

- Validates the requested clean action.
- Verifies Podman availability.
- Routes to the app-resource cleanup or image cleanup task set.

Execution note:

- This role is used by AAP-bound cleanup playbooks, so it is part of the workshop’s normal controller cleanup path.

## AAP vs Plain Ansible Summary

Prefer AAP:

- `remove_app.yml`
- `remove_image.yml`

Prefer plain `ansible-playbook`:

- `site.yml`
