# Operate Function

## Purpose

The `operate/` function provides day-2 runtime controls for the deployed Podman application stack. These playbooks assume the application has already been built and deployed.

Execution guidance:

- All current operate playbooks have matching AAP job templates, so they are intended to be run from AAP during the workshop.
- They can still be run with plain `ansible-playbook` for local testing.

## Playbooks

### `operate/playbooks/start_app.yml`

- Purpose: start previously created containers without rebuilding images.
- Role: `podman_operate` with `podman_operate_action=start`
- Execution mode: intended for AAP.

### `operate/playbooks/stop_app.yml`

- Purpose: stop running containers while preserving images, network, and volumes.
- Role: `podman_operate` with `podman_operate_action=stop`
- Execution mode: intended for AAP.

### `operate/playbooks/restart_app.yml`

- Purpose: stop and then start the stack again.
- Role: `podman_operate` with `podman_operate_action=restart`
- Execution mode: intended for AAP.

### `operate/playbooks/recycle_app.yml`

- Purpose: recycle the stack so updated runtime configuration is applied without a full redeploy.
- Role: `podman_operate` with `podman_operate_action=recycle`
- Execution mode: intended for AAP.
- Workshop significance: this is the follow-up action after automate jobs that change AI configuration or destination content.

## Roles

### `operate/roles/podman_operate`

Purpose:

- Single dispatch role for start, stop, restart, and recycle operations.

What it does:

- Validates the requested action.
- Includes the corresponding task file: `start.yml`, `stop.yml`, `restart.yml`, or `recycle.yml`.

Execution note:

- This role is the implementation behind all current operate AAP job templates.

## AAP vs Plain Ansible Summary

Prefer AAP:

- `start_app.yml`
- `stop_app.yml`
- `restart_app.yml`
- `recycle_app.yml`
