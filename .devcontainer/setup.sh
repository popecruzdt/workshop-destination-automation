#!/bin/bash
#
# Interactive setup script for Workshop Destination Automation devcontainer
# Configures dtctl for Dynatrace and generates MCP configuration for Ansible Automation Platform
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "========================================="
echo " Workshop Destination Automation Setup  "
echo "========================================="
echo ""
echo "This script will configure:"
echo "  1. dtctl CLI for Dynatrace operations"
echo "  2. MCP configuration for Ansible Automation Platform"
echo ""

# Function to prompt for input with validation
prompt_input() {
    local prompt_message=$1
    local var_name=$2
    local allow_empty=${3:-false}
    local current_value=""
    
    while true; do
        read -p "${prompt_message}: " current_value
        
        if [ -z "$current_value" ] && [ "$allow_empty" = "false" ]; then
            echo -e "${RED}Error: This field cannot be empty${NC}"
            continue
        fi
        
        eval "$var_name='$current_value'"
        break
    done
}

# Function to check if dtctl context already exists
check_dtctl_context() {
    if dtctl config current-context 2>/dev/null | grep -q "workshop"; then
        return 0
    fi
    return 1
}

# Function to test dtctl connection
test_dtctl_connection() {
    echo -e "${BLUE}Testing dtctl connection...${NC}"
    if dtctl auth whoami --plain 2>/dev/null; then
        echo -e "${GREEN}✓ dtctl connection successful${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ dtctl connection test failed (you can configure this later)${NC}"
        return 1
    fi
}

###########################################
# Part 1: Dynatrace dtctl Configuration
###########################################

echo ""
echo "========================================="
echo " Part 1: Dynatrace Configuration       "
echo "========================================="
echo ""

if check_dtctl_context; then
    echo -e "${YELLOW}Existing dtctl context 'workshop' found.${NC}"
    read -p "Do you want to reconfigure it? (y/N): " reconfigure
    
    if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing dtctl configuration${NC}"
        SKIP_DTCTL=true
    else
        SKIP_DTCTL=false
    fi
else
    SKIP_DTCTL=false
fi

if [ "$SKIP_DTCTL" = "false" ]; then
    echo "Please provide your Dynatrace environment details:"
    echo ""
    
    prompt_input "Dynatrace Environment URL (e.g., https://abc12345.apps.dynatrace.com)" DT_ENV_URL
    prompt_input "Dynatrace API Token" DT_API_TOKEN
    
    # Remove trailing slash from URL if present
    DT_ENV_URL=${DT_ENV_URL%/}
    
    # Normalize URL to use .apps.dynatrace.com format
    if [[ "$DT_ENV_URL" == *".apps.live.dynatrace.com"* ]]; then
        # Remove .live. if URL contains both .apps.live.
        DT_ENV_URL=${DT_ENV_URL//.apps.live.dynatrace.com/.apps.dynatrace.com}
        echo -e "${BLUE}Normalized URL to: $DT_ENV_URL${NC}"
    elif [[ "$DT_ENV_URL" == *".live.dynatrace.com"* ]]; then
        # Replace .live. with .apps. if URL only contains .live.
        DT_ENV_URL=${DT_ENV_URL//.live.dynatrace.com/.apps.dynatrace.com}
        echo -e "${BLUE}Normalized URL to: $DT_ENV_URL${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Configuring dtctl...${NC}"
    
    # Store credentials
    dtctl config set-credentials "workshop-token" --token "$DT_API_TOKEN"
    
    # Set context
    dtctl config set-context "workshop" \
        --environment "$DT_ENV_URL" \
        --token-ref "workshop-token"
    
    # Use the context
    dtctl config use-context "workshop"
    
    echo -e "${GREEN}✓ dtctl configured with context 'workshop'${NC}"
    
    # Test connection
    test_dtctl_connection || true
fi

###########################################
# Part 2: Ansible MCP Configuration
###########################################

echo ""
echo "========================================="
echo " Part 2: Ansible MCP Configuration     "
echo "========================================="
echo ""

MCP_JSON_PATH=".vscode/mcp.json"
MCP_BACKUP_PATH=".vscode/mcp.json.bak"
MCP_TEMPLATE_PATH=".devcontainer/mcp.json.template"

if [ -f "$MCP_JSON_PATH" ]; then
    echo -e "${YELLOW}Existing MCP configuration found at $MCP_JSON_PATH${NC}"
    read -p "Do you want to reconfigure it? (y/N): " reconfigure_mcp
    
    if [[ ! "$reconfigure_mcp" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Keeping existing MCP configuration${NC}"
        SKIP_MCP=true
    else
        SKIP_MCP=false
    fi
else
    SKIP_MCP=false
fi

if [ "$SKIP_MCP" = "false" ]; then
    echo "Please provide your Ansible Automation Platform (AAP) MCP server details:"
    echo ""
    echo "Note: The hostname should include the port (8448 by default)."
    echo "Example: destination-automation.example.com:8448"
    echo ""
    
    prompt_input "AAP MCP Server Hostname (FQDN with port)" AAP_HOSTNAME
    prompt_input "AAP Bearer Token" AAP_TOKEN
    
    # Create .vscode directory if it doesn't exist
    mkdir -p .vscode
    
    # Backup existing mcp.json if it exists
    if [ -f "$MCP_JSON_PATH" ]; then
        echo -e "${BLUE}Creating backup at $MCP_BACKUP_PATH${NC}"
        cp "$MCP_JSON_PATH" "$MCP_BACKUP_PATH"
        echo -e "${GREEN}✓ Backup created${NC}"
    fi
    
    # Generate mcp.json from template
    echo -e "${BLUE}Generating MCP configuration from template...${NC}"
    
    if [ ! -f "$MCP_TEMPLATE_PATH" ]; then
        echo -e "${RED}Error: Template file not found at $MCP_TEMPLATE_PATH${NC}"
        exit 1
    fi
    
    # Use sed to replace placeholders
    sed -e "s|{{AAP_HOSTNAME}}|${AAP_HOSTNAME}|g" \
        -e "s|{{AAP_TOKEN}}|${AAP_TOKEN}|g" \
        "$MCP_TEMPLATE_PATH" > "$MCP_JSON_PATH"
    
    echo -e "${GREEN}✓ MCP configuration generated at $MCP_JSON_PATH${NC}"
    
    # Validate JSON
    if jq empty "$MCP_JSON_PATH" 2>/dev/null; then
        echo -e "${GREEN}✓ JSON validation passed${NC}"
    else
        echo -e "${RED}✗ JSON validation failed${NC}"
        echo "Please check the generated file at $MCP_JSON_PATH"
        exit 1
    fi
    
    # Show configured servers
    echo ""
    echo -e "${BLUE}Configured MCP servers:${NC}"
    jq -r '.servers | keys[]' "$MCP_JSON_PATH" | sed 's/^/  - /'
fi

###########################################
# Part 3: Install GitHub Copilot Skills
###########################################

echo ""
echo "========================================="
echo " Part 3: GitHub Copilot Skills         "
echo "========================================="
echo ""

# Only install skills if dtctl was configured
if [ "$SKIP_DTCTL" = "false" ] || dtctl config current-context &>/dev/null; then
    echo "Installing Dynatrace AI skills for GitHub Copilot..."
    echo ""
    
    # Check if skills are already installed
    INSTALLED_SKILLS=$(dtctl skills list 2>/dev/null | grep -c "." || echo "0")
    
    if [ "$INSTALLED_SKILLS" -gt "0" ]; then
        echo -e "${YELLOW}Skills already installed (count: $INSTALLED_SKILLS)${NC}"
        read -p "Do you want to reinstall/update skills? (y/N): " reinstall_skills
        
        if [[ ! "$reinstall_skills" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Keeping existing skills${NC}"
            SKIP_SKILLS=true
        else
            SKIP_SKILLS=false
        fi
    else
        SKIP_SKILLS=false
    fi
    
    if [ "$SKIP_SKILLS" != "true" ]; then
        echo -e "${BLUE}Installing GitHub Copilot skills...${NC}"
        
        # Install skills using dtctl with explicit copilot target
        if dtctl skills install --for copilot --force 2>&1; then
            echo ""
            echo -e "${GREEN}✓ Skills installed successfully${NC}"
            
            # Show installed skills
            echo ""
            echo -e "${BLUE}Installed skills:${NC}"
            dtctl skills list 2>/dev/null | sed 's/^/  /'
            
            echo ""
            echo "These skills enable GitHub Copilot to:"
            echo "  • Execute DQL queries against Dynatrace"
            echo "  • Manage dashboards, notebooks, and workflows"
            echo "  • Query logs, metrics, and traces"
            echo "  • Create and manage SLOs"
            echo "  • Investigate problems and analyze incidents"
            
            echo ""
            echo -e "${BLUE}GitHub Copilot will automatically use these skills when you ask"
            echo -e "questions about Dynatrace, error rates, latency, logs, or observability.${NC}"
            
            # Add AI Observability reference to dtctl skills
            echo ""
            echo -e "${BLUE}Adding AI Observability reference...${NC}"
            
            SKILL_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.github/skills/dtctl"
            REFERENCES_DIR="$SKILL_DIR/references"
            AI_OBS_SOURCE=".devcontainer/ai-observability.md"
            
            if [ -f "$AI_OBS_SOURCE" ]; then
                # Copy AI Observability reference
                mkdir -p "$REFERENCES_DIR"
                cp "$AI_OBS_SOURCE" "$REFERENCES_DIR/ai-observability.md"
                
                # Add reference to SKILL.md
                if [ -f "$SKILL_DIR/SKILL.md" ]; then
                    if ! grep -q "ai-observability.md" "$SKILL_DIR/SKILL.md"; then
                        sed -i.bak '/^## Additional Resources$/a\- **AI Observability \& GenAI**: [references\/ai-observability.md](references\/ai-observability.md)' "$SKILL_DIR/SKILL.md"
                        rm -f "$SKILL_DIR/SKILL.md.bak"
                        echo -e "${GREEN}✓ AI Observability reference added to dtctl skill${NC}"
                    else
                        echo -e "${GREEN}✓ AI Observability reference already exists${NC}"
                    fi
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Failed to install skills${NC}"
            echo "  You can manually install later with: dtctl skills install --for copilot"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Skipping skill installation (dtctl not configured)${NC}"
    echo "  Configure dtctl first, then run: dtctl skills install --for copilot"
fi

###########################################
# Summary
###########################################

echo ""
echo "========================================="
echo " Configuration Complete!                "
echo "========================================="
echo ""

if [ "$SKIP_DTCTL" = "false" ]; then
    echo -e "${GREEN}✓${NC} Dynatrace dtctl configured"
    echo "  Context: $(dtctl config current-context)"
    echo "  Environment: $DT_ENV_URL"
fi

if [ "$SKIP_MCP" = "false" ]; then
    echo -e "${GREEN}✓${NC} Ansible MCP configuration generated"
    echo "  File: $MCP_JSON_PATH"
    echo "  Hostname: $AAP_HOSTNAME"
    echo "  Servers: 6 MCP endpoints configured"
fi

# Check if skills were installed
if [ "$SKIP_SKILLS" != "true" ] && dtctl config current-context &>/dev/null 2>&1; then
    SKILL_COUNT=$(dtctl skills list 2>/dev/null | wc -l | xargs)
    if [ "$SKILL_COUNT" -gt "0" ]; then
        echo -e "${GREEN}✓${NC} GitHub Copilot skills installed"
        echo "  Skills: $SKILL_COUNT Dynatrace AI skills"
    fi
fi

echo ""
echo "You can now use GitHub Copilot to:"
echo "  - Query Dynatrace using dtctl skill"
echo "  - Interact with Ansible Automation Platform via MCP"
echo ""
echo "To reconfigure at any time, run:"
echo "  .devcontainer/setup.sh"
echo ""
echo "========================================="
