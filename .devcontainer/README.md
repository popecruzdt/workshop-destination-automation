# Devcontainer Configuration for Workshop Destination Automation

This devcontainer provides a pre-configured environment for AI-assisted operations using GitHub Copilot with Ansible MCP Server and Dynatrace dtctl CLI.

## Purpose

This devcontainer is designed specifically for **AI-assisted operations** and is **not** for running the workshop's Ansible playbooks, building containers, or deploying applications. Those activities should be performed on your workshop host environment.

Use this devcontainer when you want to:
- Use GitHub Copilot to interact with Ansible Automation Platform via MCP
- Query and manage Dynatrace resources using the dtctl CLI
- Execute AI-assisted troubleshooting and operations

## What's Included

### Base Image
- `mcr.microsoft.com/devcontainers/base:debian` - Minimal Debian-based container

### Pre-installed Tools
- **dtctl** - Dynatrace CLI for managing observability resources
- **jq** - JSON processor for configuration manipulation
- **curl** - For API interactions
- **Git** - Version control

### Certificate Trust
- AAP self-signed certificate (`aap-cert.cert`) is trusted at the system level
- `NODE_EXTRA_CA_CERTS` environment variable configured for Node.js/VS Code compatibility

### VS Code Extensions
- **GitHub Copilot** - AI pair programmer
- **GitHub Copilot Chat** - Conversational AI assistance

## Files

| File | Description |
|------|-------------|
| `devcontainer.json` | Main devcontainer configuration with features and extensions |
| `Dockerfile` | Custom image with dtctl installation and certificate trust setup |
| `aap-cert.cert` | AAP self-signed certificate (copied from `ansible/aap-cert.cert`) |
| `mcp.json.template` | Template for generating `.vscode/mcp.json` with placeholders |
| `setup.sh` | Interactive configuration script for dtctl and MCP setup |
| `ai-observability.md` | AI/GenAI observability reference for dtctl skills (auto-installed) |
| `README.md` | This file |

## First-Time Setup

After the devcontainer starts, run the setup script to configure your environment:

```bash
.devcontainer/setup.sh
```

The script will prompt you for:

### Part 1: Dynatrace Configuration
- **Dynatrace Environment URL** - Your Dynatrace tenant URL (e.g., `https://abc12345.apps.dynatrace.com`)
- **Dynatrace API Token** - API token with appropriate permissions for dtctl operations

### Part 2: Ansible MCP Configuration
- **AAP MCP Server Hostname** - FQDN with port (e.g., `destination-automation.example.com:8448`)
- **AAP Bearer Token** - Authentication token for MCP server access

### Part 3: GitHub Copilot Skills
- **Install Dynatrace AI skills** - Automatically installs skills using `dtctl skills install`

The script will:
1. Configure dtctl with your Dynatrace credentials
2. Generate `.vscode/mcp.json` from the template
3. Back up existing MCP configuration (if any)
4. Validate the generated JSON configuration
5. Test the dtctl connection
6. Install GitHub Copilot skills for Dynatrace operations
7. Add AI Observability reference for GenAI/LLM tracing

## Re-running Setup

The setup script is **idempotent** - you can run it multiple times to update your configuration. It will:
- Detect existing dtctl context and ask if you want to reconfigure
- Detect existing MCP configuration and ask if you want to regenerate
- Detect existing Copilot skills and ask if you want to reinstall
- Create backups before overwriting files

## Usage with GitHub Codespaces

1. Open this repository in GitHub Codespaces
2. Wait for the devcontainer to build and start
3. Run `.devcontainer/setup.sh` to configure your environment
4. Use GitHub Copilot Chat to interact with Ansible and Dynatrace

## Verification

After setup, verify your configuration:

```bash
# Check dtctl is installed and configured
dtctl version
dtctl config current-context
dtctl auth whoami --plain

# Check installed Copilot skills
dtctl skills list

# Check 
# Check MCP configuration exists
cat .vscode/mcp.json | jq '.servers | keys'

# Verify certificate trust
echo $NODE_EXTRA_CA_CERTS
cat /etc/ssl/certs/aap-cert.pem
```

## Security Notes

- The generated `.vscode/mcp.json` contains sensitive tokens and should not be committed to version control
- `.vscode/mcp.json` is already in `.gitignore` to prevent accidental commits
- The backup file `.vscode/mcp.json.bak` is also git-ignored
- dtctl stores credentials in your system keychain (or keyring on Linux)

## Troubleshooting

### Certificate Trust Issues
If you encounter certificate validation errors when connecting to the AAP MCP server:

1. Verify the certificate is in place:
   ```bash
   ls -la /etc/ssl/certs/aap-cert.pem
   ```

2. Check the NODE_EXTRA_CA_CERTS environment variable:
   ```bash
   echo $NODE_EXTRA_CA_CERTS
   ```

3. Reload VS Code window: `Cmd+Shift+P` → "Developer: Reload Window"

### dtctl Connection Issues
If dtctl cannot connect to Dynatrace:

1. Verify your context:
   ```bash
   dtctl config describe-context $(dtctl config current-context) --plain
   ```

2. Test authentication:
   ```bash
   dtctl auth whoami --plain
   ```

3. Reconfigure by running `.devcontainer/setup.sh` again

### MCP Connection Issues
If Copilot cannot connect to Ansible MCP servers:

1. Verify the MCP configuration:
   ```bash
   jq '.' .vscode/mcp.json
   ```

2. Check that all 6 servers have the correct hostname and token

3. Regenerate configuration by running `.devcontainer/setup.sh` again

## What's NOT Included

This devcontainer intentionally does **not** include:
- Python/pip (not needed for AI operations)
- Ansible CLI tools (playbooks run on workshop host)
- Podman (container operations happen on workshop host)
- Workshop application dependencies

If you need these tools, use the workshop host environment instead of this devcontainer.
