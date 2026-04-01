# Ansible Strategy for easyTravel AI Travel Advisor Workshop

This directory is organized around six functional capabilities that map directly to workshop outcomes:

- provision
- deploy
- clean
- operate
- automate
- remediate

The goal is to make intent obvious: when we add a playbook, role, inventory, or workflow, its location should answer "what business/workshop function does this support?" before reading any YAML.

This file is the strategy and navigation document for the Ansible tree.
Use the per-function docs under each `docs/` directory for playbook and role inventories, execution details, and AAP-vs-plain-Ansible guidance.

## Design Principles

1. Function-first layout
- We group by operational function (provision/deploy/clean/operate/automate/remediate), not by technical artifact type only.
- Each function owns its playbooks, roles, variables, docs, and supporting files.

2. Workshop-safe evolution
- This workshop intentionally includes both healthy and unhealthy states for demo and teaching.
- We keep destructive or failure-inducing automation isolated under automate and remediate so normal deployment paths remain predictable.

3. Clear handoff between stages
- Provisioning infrastructure and platform is separate from deploying the app.
- Cleanup and operations are separate from deployment to avoid accidental coupling.
- Remediation is separate from automate so corrective paths remain explicit.

4. AAP-ready structure
- The folder model is designed to map cleanly to Automation Controller job templates, workflow templates, and event-driven triggers.

## Function Model

### 1) provision
- Foundational platform preparation.
- Includes AAP containerized install, Hub seeding, and custom EE/DE image builds.
- Typically plain `ansible-playbook` execution before workshop controller jobs exist.
- Details: `provision/docs/provision.md`

### 2) deploy
- Application build and release, Dynatrace deployment helpers, and AAP bootstrap administration.
- Mix of AAP-targeted workshop jobs and plain administrative bootstrap playbooks.
- Details: `deploy/docs/deploy.md`

### 3) clean
- Predictable teardown of deployed workshop resources.
- Complements deploy by removing app resources and images.
- Details: `clean/docs/clean.md`

### 4) operate
- Day-2 runtime controls such as start, stop, restart, and recycle.
- Intended to keep runtime actions separate from deployment.
- Details: `operate/docs/operate.md`

### 5) automate
- Intentional, observable workshop changes and drift scenarios.
- Safe and unsafe changes live here, not in deploy or operate.
- Details: `automate/docs/automate.md`

### 6) remediate
- Corrective actions for detected or induced failure states.
- Should remain the explicit counterpart to automate scenarios where possible.
- Details: `remediate/docs/remediate.md`

## Documentation Map

Use these files for function-specific detail:

- `provision/docs/provision.md`
- `deploy/docs/deploy.md`
- `clean/docs/clean.md`
- `operate/docs/operate.md`
- `automate/docs/automate.md`
- `remediate/docs/remediate.md`

Each function doc is the detailed source of truth for:

- current playbooks and roles
- intended execution path
- AAP versus plain `ansible-playbook` guidance
- function-specific operational notes

## Directory Structure

- provision/
  - playbooks/
  - roles/
  - inventories/
  - vars/
  - docs/
- deploy/
  - playbooks/
  - roles/
  - inventories/
  - vars/
  - docs/
- clean/
  - playbooks/
  - roles/
  - inventories/
  - vars/
  - docs/
- operate/
  - playbooks/
  - roles/
  - vars/
  - docs/
- automate/
  - playbooks/
  - roles/
  - vars/
  - workflows/
  - docs/
- remediate/
  - playbooks/
  - roles/
  - vars/
  - docs/

Top-level files retained:
- ansible.cfg
- requirements.yml
- readme.md (this strategy document)

## What Was Reorganized

To align with this strategy, prior top-level Ansible artifacts were flattened into function folders so intent is visible from the path itself.

- Playbooks now live under function-specific `playbooks/` directories.
- Roles now live under function-specific `roles/` directories.
- Inventories and variables stay close to the functions that use them.

This avoids dual layouts and makes AAP job-template mapping easier to reason about.

## AAP Credential Notes

When `deploy/playbooks/configure_aap.yml` is run, AAP creates Monaco-specific controller objects for Dynatrace platform authentication:

- Credential type:
  - `Dynatrace Monaco Platform Token`
- Credential object:
  - `destination-automation-dynatrace-monaco`

This custom credential injects the following environment variables into Monaco job template runtime:

- `DT_PLATFORM_URL`
- `DT_PLATFORM_TOKEN`

The placeholder credential is created with placeholder values unless `DT_PLATFORM_URL` and `DT_PLATFORM_TOKEN` are already exported when `configure_aap.yml` runs. After bootstrap, update the credential in AAP with the workshop Dynatrace tenant URL and platform token before launching Dynatrace deployment job templates.

## Conventions for Future Work

1. Collection module preference (AAP-aligned)
- Prefer Red Hat certified collection modules over `ansible.builtin` command or shell when a suitable module exists.
- Use `containers.podman` for container, image, and network management.
- Use the relevant controller or EDA collections when interacting with AAP.
- Document any command or shell usage when a collection module is not sufficient.

2. New content placement
- If it creates foundational platform: provision
- If it releases app workload or configures deployment dependencies: deploy
- If it tears down deployed workshop resources: clean
- If it performs day-2 runtime actions: operate
- If it drives workshop scenarios or drift via AAP: automate
- If it corrects detected failures: remediate

3. Naming guidelines
- Use action-focused playbook names such as `build_images.yml`, `restart_app.yml`, or `remediate_*.yml`.
- Keep role names aligned to reusable capability, not one-off scenario labels.

4. Demo and remediation pairing
- Any automate scenario that introduces risk should define:
  - detection expectation in Dynatrace
  - rollback or remediation strategy
  - corresponding remediate playbook when possible

5. Documentation expectations
- Add short docs under each function's `docs/` directory for:
  - purpose and scope
  - current playbooks and roles
  - whether execution is intended for AAP or plain `ansible-playbook`
  - function-specific operational notes and required variables when needed

## Strategy Intent for Future Prompts

When asked to add Ansible functionality in this repository, default to this model:
- classify the request into one of the six functions
- place playbooks, roles, vars, and docs under that function
- keep the deployment path stable
- keep cleanup isolated in clean
- keep break scenarios isolated in automate
- keep corrective actions isolated in remediate

This preserves workshop clarity, improves AAP workflow design, and makes Dynatrace-driven automation demonstrations easier to reason about and operate.
