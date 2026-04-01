# AAP 2.6 Containerized Provision Quickstart

This workflow is designed for workshop users on a fresh RHEL 9 host.

## Goal

Clone repo, set environment variables, run one playbook command to:

1. Prepare the host OS for AAP containerized install prerequisites.
2. Stage and unpack the AAP installer tarball.
3. Generate installer inventory from your environment variables.
4. Execute the Red Hat containerized installer.

## One-time setup

Run from this repository's `ansible/` directory.

## Required environment variables

```bash
# Public DNS used for Gateway URL/UI
export AAP_PUBLIC_HOSTNAME="your-instance.example.com"

# Installer source: pick ONE
# Option A: installer tarball already on host
export AAP_INSTALLER_LOCAL_PATH="$HOME/redhat/aap.tar.gz"

# Option B: download from URL
# export AAP_INSTALLER_URL="https://.../ansible-automation-platform-containerized-setup-bundle-<ver>-<arch>.tar.gz"
```

## Optional environment variables

```bash
# Set an explicit admin password before running the install
export AAP_ADMIN_PASSWORD="<set-a-strong-password>"

# Internal (private) hostname for container-to-container communication
# By default, uses the system FQDN (auto-detected by Ansible).
# This works across AWS, Azure, and GCP without modification.
# Only override if the auto-detected hostname is incorrect or inaccessible:
# export AAP_PRIVATE_HOSTNAME="internal.hostname.local"

# Install locations
export AAP_INSTALL_DIR="/opt/ansible"
export AAP_BASE_DIR="/opt/ansible/aap"

# Force rootless container runtime data out of /home/<user>
# Default is already /opt/ansible/aap/xdg if unset
export AAP_XDG_DATA_HOME="/opt/ansible/aap/xdg"

# Installer mode defaults to bundled=true
export AAP_BUNDLE_INSTALL="true"

# Keep Automation Hub installed but do not seed collections
# Defaults are already shown here for clarity
export AAP_HUB_SEED="false"
export AAP_HUB_SEED_COLLECTIONS="[]"

# Optional generated inventory destination
export AAP_INVENTORY_OUTPUT_PATH="/opt/ansible/inventory-workshop"

# Optional firewall opening for 80/443
export AAP_MANAGE_FIREWALL="true"

# Optional RHSM registration automation
export AAP_REGISTER_RHSM="false"
# If true, provide either username/password OR activation key/org:
# export RHSM_USERNAME="..."
# export RHSM_PASSWORD="..."
# export RHSM_ACTIVATION_KEY="..."
# export RHSM_ORG_ID="..."
```

## Sudo authentication

The playbook requires sudo privileges for system-level operations. How you authenticate depends on your SSH setup:

### Option A: Passwordless sudo (recommended for key-based SSH)

If you SSH using a PEM key (no password), configure passwordless sudo on the instance first:

```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
```

Then run without `-K`:

```bash
ansible-playbook provision/playbooks/install_aap_containerized.yml
```

### Option B: Interactive sudo password

If using password-based authentication, provide the sudo password interactively:

```bash
ansible-playbook provision/playbooks/install_aap_containerized.yml -K
```

### Option C: Non-interactive password via environment variable

```bash
export ANSIBLE_BECOME_PASSWORD='your-sudo-password'
ansible-playbook provision/playbooks/install_aap_containerized.yml
```

## Single command run

**For key-based SSH (most common for cloud VMs):**

```bash
ansible-playbook provision/playbooks/install_aap_containerized.yml
```

**For password-based auth:**

```bash
ansible-playbook provision/playbooks/install_aap_containerized.yml -K
```

## Notes

1. The playbook enforces key prerequisites from Red Hat docs (FQDN, repos, packages, disk space).
2. For bundled installs, generated inventory includes `bundle_install=true` and computed `bundle_dir`.
3. Generated inventory sets `hub_seed=false` and `hub_seed_collections=[]` by default.
4. Installer execution is run with `XDG_DATA_HOME=/opt/ansible/aap/xdg` by default to avoid placing container assets under `/home/<user>`.
5. Installer execution is skipped if `controller_data_dir` already exists.
6. To force a reinstall, clean previous AAP runtime data and rerun.

## Optional post-install Automation Hub seeding

The main install workflow disables bundled collection seeding by default for faster workshop provisioning.

If you want to seed the bundled Automation Hub collections after AAP is already installed, run:

```bash
ansible-playbook provision/playbooks/seed_hub_collections.yml
```

This seeding workflow:

1. Reuses the existing generated installer inventory.
2. Uploads bundled collections into Automation Hub only.
3. Does not rerun the full AAP platform installation.
4. Writes progress to `aap_hub_seed.log` under the extracted installer directory and prints periodic log excerpts while it runs.

## Build custom execution environment for containers.podman

After AAP install (and optional Hub seeding), build a custom execution environment for workshop job templates:

```bash
ansible-playbook provision/playbooks/build_custom_ee.yml
```

### Minimal Podman-only Profile (Recommended to avoid dependency conflicts)

By default, the role now builds a **minimal, conflict-free execution environment**:

1. Builds `destination-automation-ee:latest` from `ee-supported-rhel9:2.0`.
2. Includes **only** `containers.podman` (pinned version for reproducibility).
3. Removes optional mixed-use collections (awx.awx, community.general, dynatrace.oneagent) to minimize dependency resolver conflicts.
4. Reduces system package footprint to only essentials required for Podman workload management.

**Recommended workflow:** Build locally first, validate success, then push to registry:

```bash
# Step 1: Build locally only (fastest validation)
export EE_PUSH_TO_REGISTRY="false"
ansible-playbook provision/playbooks/build_custom_ee.yml

# Step 2: Verify image exists and is ready
podman image inspect localhost/destination-automation-ee:latest

# Step 3: If local build succeeded, push to registry
export EE_PUSH_TO_REGISTRY="true"
export EE_REGISTRY_HOST="$(hostname -f)"
export EE_REGISTRY_USERNAME="admin"
export EE_REGISTRY_PASSWORD="${AAP_ADMIN_PASSWORD}"
export EE_REGISTRY_VALIDATE_CERTS="false"
ansible-playbook provision/playbooks/build_custom_ee.yml
```

### Dependency Versions (Pinned for Reproducibility)

| Component | Version | Note |
|-----------|---------|------|
| Base Image | ee-supported-rhel9:2.0 | Red Hat Certified EE runtime |
| containers.podman | 1.15.0 | Stable release for AAP 2.6 on RHEL 9 |
| ansible-builder | 3.7.0 | Stable 3.x release for schema v3 |

### If you need mixed-use collections

If your job templates also require `awx.awx`, `community.general`, or other collections, create a **separate** EE profile by:

1. Setting `EE_PROFILE_MIXED_USE=true` (future enhancement)
2. Or manually updating [templates/requirements.yml.j2](../roles/build_custom_ee/templates/requirements.yml.j2) with additional collections
3. Understanding that mixed-use EEs have higher risk of dependency conflicts and longer build times

### Troubleshooting build failures

If the build still fails:

1. Check the rendered dependency manifests in the playbook output (they are now logged before the build starts).
2. Verify `podman` and `python3` are available on your build host.
3. Ensure the base image `ee-supported-rhel9:2.0` is accessible from your registry.
4. Try a clean rebuild with a fresh work directory: `rm -rf /tmp/ee-build-*`

Then register/update the execution environment in Controller:

```bash
ansible-playbook deploy/playbooks/configure_aap.yml
```
