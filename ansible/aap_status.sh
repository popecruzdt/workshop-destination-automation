#!/usr/bin/env bash

# AAP containerized quick health summary.
# Prints a green/yellow/red report for service, API, and container status.

set -u

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ok_count=0
warn_count=0
err_count=0

EXPECTED_SERVICES=(
  postgresql.service
  redis-unix.service
  redis-tcp.service
  automation-gateway-proxy.service
  automation-gateway.service
  receptor.service
  automation-controller-rsyslog.service
  automation-controller-task.service
  automation-controller-web.service
  automation-eda-api.service
  automation-eda-daphne.service
  automation-eda-web.service
  automation-eda-worker-1.service
  automation-eda-worker-2.service
  automation-eda-activation-worker-1.service
  automation-eda-activation-worker-2.service
  automation-eda-scheduler.service
  automation-hub-api.service
  automation-hub-content.service
  automation-hub-web.service
  automation-hub-worker-1.service
  automation-hub-worker-2.service
)

print_header() {
  echo -e "${BOLD}${BLUE}AAP Health Summary${NC}"
  echo "Host: $(hostname -f 2>/dev/null || hostname)"
  echo "User: $(id -un) (uid=$(id -u))"
  echo "Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo
}

print_ok() {
  echo -e "${GREEN}[GREEN]${NC} $*"
  ok_count=$((ok_count + 1))
}

print_warn() {
  echo -e "${YELLOW}[YELLOW]${NC} $*"
  warn_count=$((warn_count + 1))
}

print_err() {
  echo -e "${RED}[RED]${NC} $*"
  err_count=$((err_count + 1))
}

check_systemctl_user_available() {
  if ! command -v systemctl >/dev/null 2>&1; then
    print_err "systemctl is not installed on this host."
    return 1
  fi

  if ! systemctl --user list-unit-files --type=service --no-legend --no-pager >/dev/null 2>&1; then
    print_warn "Cannot query user-level systemd services in this session."
    print_warn "Try running from a normal login shell as the AAP install user (not sudo/root)."
    return 1
  fi

  return 0
}

check_services() {
  echo -e "${BOLD}Service Checks${NC}"

  if ! check_systemctl_user_available; then
    echo
    return 1
  fi

  local unit_files
  unit_files="$(systemctl --user list-unit-files --type=service --no-legend --no-pager 2>/dev/null | awk '{print $1}')"

  local missing_count=0
  local active_count=0
  local failed_count=0

  for svc in "${EXPECTED_SERVICES[@]}"; do
    if ! grep -qx "$svc" <<<"$unit_files"; then
      print_err "$svc: missing (not installed on this host/user profile)"
      missing_count=$((missing_count + 1))
      continue
    fi

    state="$(systemctl --user is-active "$svc" 2>/dev/null || true)"
    case "$state" in
      active)
        print_ok "$svc: active"
        active_count=$((active_count + 1))
        ;;
      activating|reloading)
        print_warn "$svc: $state"
        ;;
      inactive|deactivating)
        print_warn "$svc: $state"
        ;;
      failed)
        print_err "$svc: failed"
        failed_count=$((failed_count + 1))
        ;;
      *)
        print_warn "$svc: unknown state (${state:-unavailable})"
        ;;
    esac
  done

  echo
  echo "Service summary: active=$active_count, missing=$missing_count, failed=$failed_count, expected=${#EXPECTED_SERVICES[@]}"

  if [[ "$missing_count" -eq "${#EXPECTED_SERVICES[@]}" ]]; then
    echo
    print_err "All expected AAP services are missing."
    echo "Did you install AAP containerized on this host?"
    echo "If not, follow: provision/docs/aap_containerized_quickstart.md"
  fi

  echo
  return 0
}

check_api() {
  echo -e "${BOLD}API Checks${NC}"

  if ! command -v curl >/dev/null 2>&1; then
    print_warn "curl is not installed; skipping API checks."
    echo
    return
  fi

  local host="${AAP_PUBLIC_HOSTNAME:-localhost}"
  local base_url="https://${host}"

  check_url() {
    local label="$1"
    local url="$2"
    local accepted="$3"

    code="$(curl -k -sS -o /dev/null --connect-timeout 5 --max-time 12 -w '%{http_code}' "$url" 2>/dev/null || echo '000')"

    if [[ " $accepted " == *" $code "* ]]; then
      print_ok "$label ($url): HTTP $code"
    elif [[ "$code" == "000" ]]; then
      print_err "$label ($url): no response"
    else
      print_warn "$label ($url): HTTP $code"
    fi
  }

  check_url "Gateway" "$base_url/" "200 301 302 401"
  check_url "Controller ping" "$base_url/api/controller/v2/ping/" "200 401"
  check_url "Gateway ping" "$base_url/api/gateway/v1/ping/" "200 401"

  echo
}

check_podman() {
  echo -e "${BOLD}Container Checks${NC}"

  if ! command -v podman >/dev/null 2>&1; then
    print_warn "podman is not installed; skipping container checks."
    echo
    return
  fi

  local uid
  uid="$(id -u)"
  local podman_root="${AAP_XDG_DATA_HOME:-/opt/ansible/aap/xdg}/containers/storage"
  local podman_runroot="/run/user/${uid}/containers"

  names="$(podman --root "$podman_root" --runroot "$podman_runroot" ps --format '{{.Names}}' 2>/dev/null || true)"

  if [[ -z "$names" ]]; then
    print_warn "No running containers found in rootless store."
    echo "Checked: --root $podman_root --runroot $podman_runroot"
    echo
    return
  fi

  local aap_count
  aap_count="$(grep -Ec '^(automation-|postgresql$|redis-(unix|tcp)$|receptor$)' <<<"$names" || true)"

  if [[ "$aap_count" -gt 0 ]]; then
    print_ok "Found $aap_count running AAP containers in rootless podman storage."
  else
    print_warn "Running containers found, but none match expected AAP names."
  fi

  echo "Checked: --root $podman_root --runroot $podman_runroot"
  echo
}

print_footer() {
  echo -e "${BOLD}Overall${NC}"

  if [[ "$err_count" -eq 0 && "$warn_count" -eq 0 ]]; then
    echo -e "${GREEN}HEALTH: GREEN${NC}"
  elif [[ "$err_count" -eq 0 ]]; then
    echo -e "${YELLOW}HEALTH: YELLOW${NC}"
  else
    echo -e "${RED}HEALTH: RED${NC}"
  fi

  echo "Counters: green=$ok_count yellow=$warn_count red=$err_count"
}

print_header
check_services
check_api
check_podman
print_footer
