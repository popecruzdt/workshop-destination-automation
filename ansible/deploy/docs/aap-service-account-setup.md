# AAP Service Account Setup Guide

## Overview

Automation in AAP requires a dedicated service account on the target RHEL 9 instance for SSH-based job execution. This service account will be used by AAP to authenticate and run automation tasks, separate from your personal SSH access.

**Service Account Name:** `aap-service-account`

## Prerequisites

- Access to the RHEL 9 instance with `sudo` privileges
- Your SSH private key file used to access the instance (for example, a `.pem` file)
- SSH access to the RHEL 9 instance

## Step 1: Create the Service Account

SSH into the RHEL 9 instance as a user with `sudo` privileges:

```bash
ssh <your-user>@<rhel-instance>
```

Create the service account:

```bash
sudo useradd -m -s /bin/bash aap-service-account
```

Verify the account was created:

```bash
id aap-service-account
```

You should see output similar to:
```
uid=1001(aap-service-account) gid=1001(aap-service-account) groups=1001(aap-service-account)
```

## Step 2: Configure SSH Public Key Authentication

SSH authentication works as a matched pair: the **private key** (your `.pem` file) is what you use to log in, and the **public key** is what the server stores in `authorized_keys` to verify your private key is allowed. The current login user's account already has the matching public key configured, because that is how you authenticated to the instance. We need to add the same public key to `aap-service-account`'s `authorized_keys` so AAP can authenticate as that user using your `.pem`.

**On the RHEL instance**, set up the `.ssh` directory for the service account:

```bash
sudo -u aap-service-account mkdir -p /home/aap-service-account/.ssh
sudo chmod 700 /home/aap-service-account/.ssh
```

Add the public key to `authorized_keys` using one of these approaches. Since you're already on the instance, you can either copy the current login user's existing `authorized_keys` entry, or extract the public key directly from your `.pem` file.

### Option A: Copy from the current login user's authorized_keys (Recommended)

The public key that matches the key you used to log in is already available in the current login user's `authorized_keys`. Copy it directly:

```bash
current_user_home="$(getent passwd "$(whoami)" | cut -d: -f6)"
sudo cp "$current_user_home/.ssh/authorized_keys" /home/aap-service-account/.ssh/authorized_keys
sudo chown aap-service-account:aap-service-account /home/aap-service-account/.ssh/authorized_keys
sudo chmod 600 /home/aap-service-account/.ssh/authorized_keys
```

### Option B: Extract public key from your .pem file

If you have the `.pem` file available on the RHEL instance, extract the public key from it:

```bash
# Extract the public key from the .pem private key file
ssh-keygen -y -f /path/to/your-key.pem | sudo tee /home/aap-service-account/.ssh/authorized_keys > /dev/null
sudo chown aap-service-account:aap-service-account /home/aap-service-account/.ssh/authorized_keys
sudo chmod 600 /home/aap-service-account/.ssh/authorized_keys
```

## Step 3: Verify SSH Access

Test that you can SSH as the service account:

```bash
ssh -i /path/to/your-key.pem aap-service-account@<rhel-instance>
```

You should successfully connect without being prompted for a password. If successful, you should be in the service account's home directory.

Type `exit` to close the connection.

## Step 4: Enable Systemd Lingering (REQUIRED for Container Jobs)

**Critical for Podman-based jobs:** AAP job service accounts running rootless Podman must have systemd lingering enabled. Without lingering, containers will be terminated when the job process exits, preventing long-running container stacks from persisting across job completions.

Enable lingering for the service account:

```bash
sudo loginctl enable-linger aap-service-account
```

Verify it was enabled successfully:

```bash
loginctl list-users
```

You should see output similar to:
```
 UID USER                LINGER STATE    
1000 ec2-user            yes    active
1001 aap-service-account yes    lingering
```

**Why this is necessary:**
- Without lingering, systemd kills the user session when the job completes
- This immediately terminates all containers in that namespace (even with `restart_policy: unless-stopped`)
- With lingering enabled, containers persist in the background and survive job completion and system reboots
- This enables long-running application stacks to remain accessible after deployment jobs finish

## Step 5: Configure Podman Log Driver

By default, the `aap-service-account` user's Podman uses the `k8s-file` log driver, which stores container logs in paths tied to the container's layer ID. This means logs are lost every time a container is recreated (e.g., after running the recycle job template). Configuring the `journald` log driver persists logs across container recreations and makes them accessible via `journalctl`.

Create the Podman configuration directory and set the log driver:

```bash
sudo mkdir -p /home/aap-service-account/.config/containers
sudo tee /home/aap-service-account/.config/containers/containers.conf > /dev/null << 'EOF'
[containers]
log_driver = "journald"
EOF
sudo chown -R aap-service-account:aap-service-account /home/aap-service-account/.config
```

Verify the configuration was written correctly:

```bash
sudo cat /home/aap-service-account/.config/containers/containers.conf
```

Expected output:
```
[containers]
log_driver = "journald"
```

After this configuration is applied, all containers started by AAP jobs will write logs to the systemd journal. You can then view logs with:

```bash
sudo -u aap-service-account journalctl --user -t travel-advisor -f
```

**Note:** This change only affects containers created after the configuration is set. Existing containers retain their original log driver. Re-running the `recycle-app` job template will recreate the `travel-advisor` container with the new `journald` driver.

## Step 6: Grant Full Sudo for OneAgent Deployment (Required)

The `deploy_dynatrace_oneagent.yml` playbook (role: `dynatrace_oneagent_deploy`) requires full `sudo` privileges to install and configure Dynatrace OneAgent on Linux.

Dynatrace installation reference:
https://docs.dynatrace.com/docs/ingest-from/dynatrace-oneagent/installation-and-operation/linux/installation/install-oneagent-on-linux

Run these commands on the target RHEL node to grant full passwordless sudo to `aap-service-account`:

```bash
sudo tee /etc/sudoers.d/aap-service-account-full-sudo > /dev/null << 'EOF'
aap-service-account ALL=(ALL) NOPASSWD: ALL
EOF
sudo chmod 440 /etc/sudoers.d/aap-service-account-full-sudo
sudo visudo -cf /etc/sudoers.d/aap-service-account-full-sudo
```

If validation succeeds, you should see:
```
/etc/sudoers.d/aap-service-account-full-sudo: parsed OK
```

## Step 6b: Remove Full Sudo After OneAgent (Optional)

After OneAgent is installed, you may keep full sudo or remove it. Removal is optional and depends on your security policy.

To remove full sudo access:

```bash
sudo rm -f /etc/sudoers.d/aap-service-account-full-sudo
sudo visudo -c
```

To confirm access was removed:

```bash
sudo -u aap-service-account sudo -n true
```

Expected result: command should fail with a sudo permission error.

## Step 7: Update the Machine Credential in AAP

The AAP automation will create a Machine credential named `aap-service-account` without an SSH key. You need to add your `.pem` private key so AAP can authenticate as `aap-service-account` on the RHEL instance:

1. **Log in to AAP** using your workshop credentials
2. **Navigate to:** Credentials (in the left sidebar)
3. **Find and click** the `aap-service-account` credential
4. **Click Edit** (pencil icon)
5. **Locate the SSH private key field** and click the text area
6. **Paste the full contents of your `.pem` file** — open it in a text editor on your local machine and copy everything, including:
   - The `-----BEGIN RSA PRIVATE KEY-----` header (or `-----BEGIN OPENSSH PRIVATE KEY-----` for newer keys)
   - All lines of base64-encoded key data
   - The `-----END RSA PRIVATE KEY-----` footer (or `-----END OPENSSH PRIVATE KEY-----`)
7. **Click Save**

**Important Security Notes:**
- Your private key is encrypted and stored securely in AAP's credential vault
- Private keys are never displayed in logs or output
- Only authorized users can access credentials in AAP

## Step 8: Verify Job Execution

Once the credential is configured, AAP job templates that target the private hostname will authenticate as `aap-service-account` and execute your playbooks.

To verify everything is working:

1. Navigate to **Job Templates** in AAP
2. Find and launch the **`destination-automation-node-readiness`** template
3. Monitor the job output in the **Details** tab
4. Verify that tasks execute successfully on the target node

## Troubleshooting

### "Permission denied (publickey)" Error

- Verify the service account was created: `id aap-service-account`
- Verify authorized_keys has correct permissions: `ls -la /home/aap-service-account/.ssh/`
- Verify your public key is in authorized_keys: `sudo cat /home/aap-service-account/.ssh/authorized_keys`
- Test manual SSH: `ssh -i /path/to/your-key.pem aap-service-account@<rhel-instance>`

### AAP Job Failure with Authentication Error

- Confirm the Machine credential was updated with your actual private key (not the placeholder)
- Verify no extra whitespace was added when pasting the private key
- Check that the private key file format is correct (PEM format)

### SSH Fails but You Can SSH as Your User

- Verify you used the correct SSH key: `ssh -i /path/to/your-key.pem aap-service-account@<rhel-instance>`
- Confirm SSH is not requiring a password (should not prompt)
- If the host key is unfamiliar, you may need to accept it first

## Additional Information

- The `aap-service-account` is used exclusively for AAP automation
- Your personal user account remains unchanged
- Multiple workshop participants can each add their own public key to `authorized_keys` on the same service account
- This approach keeps audit logs clean—jobs executed by AAP are logged under `aap-service-account`

For questions about AAP job execution or credential management, consult the workshop instructors or AAP documentation.
