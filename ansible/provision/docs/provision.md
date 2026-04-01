# Provision Function

## Purpose

The `provision/` function prepares and bootstraps foundational platform components for the workshop, especially AAP containerized installation and custom execution environment images.

Execution guidance:

- These playbooks are currently plain-Ansible workflows.
- No matching AAP job templates are defined for the provision playbooks in the current controller bootstrap role.
- In practice, provision is used before the AAP workshop environment is fully configured.

## Playbooks

### `provision/playbooks/install_aap_containerized.yml`

- Purpose: perform the all-in-one AAP 2.6 containerized installation.
- Role: `aap_containerized_install`
- Execution mode: plain Ansible.

### `provision/playbooks/seed_hub_collections.yml`

- Purpose: seed bundled Automation Hub collections after AAP has already been installed.
- Role/task entry: `aap_containerized_install` with `tasks_from: seed_hub.yml`
- Execution mode: plain Ansible.
- Operational note: explicitly documented as post-install only.

### `provision/playbooks/seed_hub_collections_inner.yml`

- Purpose: internal helper playbook used by the Hub seeding workflow.
- Execution mode: internal plain-Ansible helper only.
- Operational note: not intended for direct operator use.

### `provision/playbooks/build_custom_ee.yml`

- Purpose: build and optionally push custom execution environment images for AAP.
- Role: `build_custom_ee`
- Execution mode: plain Ansible.
- Follow-up: intended to be registered later in AAP with `deploy/playbooks/configure_aap.yml` or administrative updates.

### `provision/playbooks/build_custom_de.yml`

- Purpose: build a custom decision environment image for EDA rulebook activations.
- Role: `build_custom_de`
- Execution mode: plain Ansible.
- Follow-up: intended to be registered later with `deploy/playbooks/configure_eda.yml`.

## Roles

### `provision/roles/aap_containerized_install`

- Used by `install_aap_containerized.yml` and the Hub seeding flow.
- Major responsibilities:
  - run preflight checks
  - prepare the host OS
  - stage the installer and extracted content
  - build the installer inventory
  - execute the installer
  - validate the resulting AAP installation

### `provision/roles/build_custom_ee`

- Used by `build_custom_ee.yml`.
- Installs or validates `ansible-builder`, prepares Podman and registry access, builds execution-environment profiles, and summarizes/pushes results.

### `provision/roles/build_custom_de`

- Used by `build_custom_de.yml`.
- Mirrors the EE build pattern for decision environments, including builder validation, registry setup, working-directory preparation, and build profile execution.

## AAP vs Plain Ansible Summary

Prefer plain `ansible-playbook`:

- `install_aap_containerized.yml`
- `seed_hub_collections.yml`
- `seed_hub_collections_inner.yml`
- `build_custom_ee.yml`
- `build_custom_de.yml`
