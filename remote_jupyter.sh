#!/usr/bin/env bash
set -eu

REMOTE_PORT_DEFAULT=8889
LOCAL_PORT_DEFAULT=8889
MAX_WAIT=30   # seconds to poll for Jupyter startup

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] user@host
       $(basename "$0") stop [options] user@host

Without 'stop': connect to Jupyter Lab on remote (start if not running).

Options:
  -r PORT   Remote port (default ${REMOTE_PORT_DEFAULT})
  -l PORT   Local port  (default ${LOCAL_PORT_DEFAULT})
  -d DIR    Remote notebook-dir (default: remote home; ignored when already running)
EOF
}

[ $# -lt 1 ] && { usage; exit 1; }
CMD="start"
if [ "$1" = "stop" ]; then
  CMD="stop"
  shift
fi

REMOTE_PORT=${REMOTE_PORT_DEFAULT}
LOCAL_PORT=${LOCAL_PORT_DEFAULT}
NOTEBOOK_DIR=""

while getopts "hr:l:d:" o; do
  case "${o}" in
    h) usage; exit 0;;
    r) REMOTE_PORT="${OPTARG}";;
    l) LOCAL_PORT="${OPTARG}";;
    d) NOTEBOOK_DIR="${OPTARG}";;
    *) usage; exit 1;;
  esac
done
shift $((OPTIND-1))

[ $# -lt 1 ] && { usage; exit 2; }
HOST="$1"

re='^[0-9]+$'
[[ ${REMOTE_PORT} =~ ${re} && ${LOCAL_PORT} =~ ${re} ]] \
  || { echo "Ports must be integers" >&2; exit 2; }

# Returns 0 if a Jupyter server is already listening on REMOTE_PORT on HOST
remote_jupyter_running() {
  ssh "${HOST}" "zsh -l -c 'source ~/.zshrc 2>/dev/null; jupyter server list --json 2>/dev/null'" 2>/dev/null \
    | grep -qE '"port":[[:space:]]*'"${REMOTE_PORT}"'[,}]'
}

open_browser() {
  if command -v open >/dev/null 2>&1; then
    open "$1"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$1" >/dev/null 2>&1 || true
  else
    echo "Open manually: $1"
  fi
}

case "${CMD}" in
  start)
    if remote_jupyter_running; then
      echo "Jupyter Lab already running on ${HOST}:${REMOTE_PORT}."
    else
      DIR_ARG=""
      [ -n "${NOTEBOOK_DIR}" ] && DIR_ARG="--notebook-dir=${NOTEBOOK_DIR}"
      echo "Starting Jupyter Lab on ${HOST}:${REMOTE_PORT}..."
      # Note: --IdentityProvider.token= requires Jupyter Server >=2 (Lab >=4).
      #       For older installs, replace with --ServerApp.token=
      ssh "${HOST}" "zsh -l -c 'source ~/.zshrc 2>/dev/null; nohup jupyter lab --no-browser --port=${REMOTE_PORT} --IdentityProvider.token= ${DIR_ARG} >/tmp/jupyter_${REMOTE_PORT}.log 2>&1 </dev/null &'"

      printf "Waiting for Jupyter"
      elapsed=0
      until remote_jupyter_running; do
        printf "."
        sleep 1
        elapsed=$((elapsed + 1))
        if [ "${elapsed}" -ge "${MAX_WAIT}" ]; then
          printf "\n"
          echo "Timed out after ${MAX_WAIT}s. Check ${HOST}:/tmp/jupyter_${REMOTE_PORT}.log" >&2
          exit 5
        fi
      done
      printf " ready\n"
    fi

    # Open SSH tunnel if not already present
    if lsof -i :"${LOCAL_PORT}" -a -c ssh >/dev/null 2>&1; then
      echo "SSH tunnel on local port ${LOCAL_PORT} already exists."
    else
      echo "Opening tunnel  localhost:${LOCAL_PORT} -> ${HOST}:${REMOTE_PORT}"
      ssh -N -f -L "localhost:${LOCAL_PORT}:localhost:${REMOTE_PORT}" "${HOST}" \
        || { echo "SSH tunnel failed" >&2; exit 4; }
    fi

    URL="http://localhost:${LOCAL_PORT}/"
    echo "→ ${URL}"
    open_browser "${URL}"
    ;;

  stop)
    # Stop remote Jupyter first (direct SSH; tunnel not required)
    echo "Stopping Jupyter Lab on ${HOST}:${REMOTE_PORT}..."
    ssh "${HOST}" "zsh -l -c 'source ~/.zshrc 2>/dev/null; jupyter server stop ${REMOTE_PORT} 2>/dev/null || pkill -f \"jupyter.*${REMOTE_PORT}\" 2>/dev/null || true'" || true

    # Kill local SSH tunnel (filter by process name to avoid false positives)
    TUNNEL_PIDS="$(lsof -ti :"${LOCAL_PORT}" -a -c ssh 2>/dev/null || true)"
    if [ -n "${TUNNEL_PIDS}" ]; then
      echo "Killing SSH tunnel (PID ${TUNNEL_PIDS})..."
      echo "${TUNNEL_PIDS}" | xargs kill
    else
      echo "No SSH tunnel found on local port ${LOCAL_PORT}."
    fi

    echo "Done."
    ;;

  *)
    echo "Unknown command: ${CMD}" >&2
    usage; exit 1
    ;;
esac
