#!/usr/bin/env bash
set -euo pipefail

# Parses named arguments into global script variables.
#
# Sets base_url, remote_alias and project_dir.
#
# Args:
#     args: Arguments passed to the script.
#
# Returns:
#     None. Exits with status 1 if required arguments are missing.
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -u|--url)
        base_url="$2"; shift 2 ;;
      -a|--alias)
        remote_alias="$2"; shift 2 ;;
      -p|--path)
        project_dir="$2"; shift 2 ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        echo "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
  base_url="${base_url:?ERROR: missing --url}"
  remote_alias="${remote_alias:?ERROR: missing --alias}"
  project_dir="${project_dir:?ERROR: missing --path}"
}

# Prints usage information.
usage() {
  echo "Usage: $0 -u <url> -a <ssh-alias> -p <remote-project-path>"
  echo "  -u, --url     WordPress base URL, e.g. http://203.0.113.10:8080"
  echo "  -a, --alias   SSH host alias from ~/.ssh/config"
  echo "  -p, --path    Project directory on the remote host"
}

# Checks HTTP accessibility of the WordPress installation.
#
# Prints a confirmation message only on success.
#
# Returns:
#     0 if the site answers with 200 or 302, 1 otherwise.
check_remote() {
  local status=""
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${base_url}" || echo "000")
  [[ "${status}" =~ ^00+$ ]] && status="000"
  if [[ "${status}" = "200" || "${status}" = "302" ]]; then
    echo "Server responds with HTTP status ${status}"
    return 0
  fi
  return 1
}
# Stores a unique test token inside the WordPress data volume.
#
# Args:
#     token: Value to persist in the data volume.
#
# Returns:
#     0 on success, 1 otherwise.
store_test_token() {
  local token="$1"
  ssh "${remote_alias}" "docker exec ${container_name} sh -c 'echo ${token} > /var/www/html/.persistence-token'"
}

# Reads the test token back from the WordPress data volume.
#
# Returns:
#     0 and prints the stored token, or 1 on failure.
read_test_token() {
  ssh "${remote_alias}" "docker exec ${container_name} cat /var/www/html/.persistence-token 2>/dev/null" || return 1
}
# Determines the WordPress application container name on the remote host.
#
# Args:
#     None. Uses remote_alias.
#
# Returns:
#     0 and prints the container name, or 1 if no container is found.
get_container_name() {
  local name=""
  name=$(ssh "${remote_alias}" "docker ps -a --filter 'name=wordpress' --format '{{.Names}}' | head -1")
  if [[ -z "${name}" ]]; then
    return 1
  fi
  echo "${name}"
}

# Runs all end-to-end checks against the remote WordPress stack.
#
# Args:
#     args: Script arguments forwarded to parse_arguments.
#
# Returns:
#     0 if all checks pass, exits with 1 on the first failure.
main() {
  parse_arguments "$@"

  local container_name=""
  container_name=$(get_container_name) || { echo "FAIL: No container found on ${remote_alias}"; exit 1; }

  echo "[1] Remote availability"
  check_remote || { echo "FAIL: WordPress not reachable"; exit 1; }
  echo "PASS"

  local test_token=""
  test_token="persistence-check-$(date +%s)"
  store_test_token "${test_token}" || { echo "FAIL: Could not write test token"; exit 1; }
  echo "Data stored for persistence test: ${test_token}"

  echo "[2] Shutting down stack on remote"
  ssh "${remote_alias}" "cd ${project_dir} && docker compose down >/dev/null 2>&1"

  echo "[3] Waiting up to 20s for container status 'down'"
  local is_down="false"
  for i in $(seq 1 20); do
    if ! check_remote >/dev/null; then
      is_down="true"
      break
    fi
    sleep 1
  done
  [[ "${is_down}" == "true" ]] || { echo "FAIL: Site still reachable after shutdown"; exit 1; }
  echo "PASS: Site unreachable after ${i}s"

  echo "[4] Starting stack again on remote"
  ssh "${remote_alias}" "cd ${project_dir} && docker compose up -d >/dev/null 2>&1"

  echo "[5] Waiting up to 30s for WordPress to answer"
  local is_up="false"
  for i in $(seq 1 30); do
    if check_remote >/dev/null; then
      is_up="true"
      break
    fi
    sleep 1
  done
  [[ "${is_up}" == "true" ]] || { echo "FAIL: WordPress did not recover"; exit 1; }

  echo "[6] Verifying persisted data on remote"
  local restored_token=""
  restored_token=$(read_test_token) || { echo "FAIL: Test token not readable"; exit 1; }
  [[ "${restored_token}" = "${test_token}" ]] || { echo "FAIL: Test token mismatch (volume not persisted)"; exit 1; }
  echo "Data read from the restarted Container: ${restored_token}"
  echo "PASS: Site back with persisted data"

  echo "[7] Crash test: killing PID 1 in wordpress container"
  local state_before=""
  local started_at_before=""
  local restarts_before=""
  state_before=$(ssh "${remote_alias}" "docker inspect -f '{{.State.StartedAt}} {{.RestartCount}}' ${container_name}")
  started_at_before=$(echo "${state_before}" | awk '{print $1}')
  restarts_before=$(echo "${state_before}" | awk '{print $2}')
  echo "Container started before termination: ${started_at_before}"
  echo "Number of Restarts before termination: ${restarts_before}"
  ssh "${remote_alias}" "docker exec ${container_name} kill 1"

  echo "[8] Container restarted after crash?"
  local is_restarted="false"
  local inspect=""
  local status_field=""
  local started_at_after=""
  local restarts_after=""
  for i in $(seq 1 20); do
    inspect=$(ssh "${remote_alias}" "docker inspect -f '{{.State.Status}} {{.State.StartedAt}} {{.RestartCount}}' ${container_name}")
    status_field=$(echo "${inspect}" | awk '{print $1}')
    started_at_after=$(echo "${inspect}" | awk '{print $2}')
    restarts_after=$(echo "${inspect}" | awk '{print $3}')
    if [[ "${status_field}" = "running" && "${restarts_after}" -gt "${restarts_before}" ]]; then
      is_restarted="true"
      break
    fi
    sleep 1
  done
  [[ "${is_restarted}" == "true" ]] || { echo "FAIL: ${inspect:-no restart detected}"; exit 1; }
  echo "Container started after restart: ${started_at_after}"
  echo "Actual Number of Restarts: ${restarts_after}"
  echo "PASS"

  echo "ALL CHECKS PASSED"
}

main "$@"