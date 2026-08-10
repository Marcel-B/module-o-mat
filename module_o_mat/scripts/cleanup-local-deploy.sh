#!/usr/bin/env bash
# Removes a local module-o-mat deploy from this host (Docker stack, images, volumes, source dirs).
# Usage (on the Proxmox CT):
#   curl -fsSL https://raw.githubusercontent.com/Marcel-B/module-o-mat/feature/deployment/module_o_mat/scripts/cleanup-local-deploy.sh | bash
#   # or after downloading:
#   bash cleanup-local-deploy.sh
#   bash cleanup-local-deploy.sh --yes   # skip confirmation

set -euo pipefail

ASSUME_YES=0
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  ASSUME_YES=1
fi

DIRS=(
  /opt/module-o-mat
  /root/module-o-mat
  /root/module_o_mat
)

echo "=== module-o-mat local deploy cleanup ==="
echo
echo "This will remove:"
echo "  - Docker containers/compose stacks matching module_o_mat / module-o-mat"
echo "  - Locally built images (e.g. module_o_mat-web) and dangling images"
echo "  - Docker volumes matching module_o_mat"
echo "  - Source directories (if present):"
for d in "${DIRS[@]}"; do
  echo "      $d"
done
echo
echo "GHCR images are only removed from this host's Docker cache, not from GitHub."
echo

if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found; skipping container/image/volume cleanup."
else
  # Stop compose projects in known dirs (ignore failures)
  for d in "${DIRS[@]}"; do
    for compose_dir in "$d" "$d/module_o_mat"; do
      if [[ -f "$compose_dir/docker-compose.yml" || -f "$compose_dir/compose.yml" ]]; then
        echo "→ docker compose down in $compose_dir"
        (cd "$compose_dir" && docker compose down --rmi local --volumes --remove-orphans) || true
      fi
    done
  done

  echo "→ Removing matching containers"
  docker ps -aq --filter "name=module_o_mat" | xargs -r docker rm -f || true
  docker ps -aq --filter "name=module-o-mat" | xargs -r docker rm -f || true

  echo "→ Removing matching images"
  # Local compose build name + any tagged module_o_mat / module-o-mat images on this host
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
    | awk 'tolower($0) ~ /module[_-]o[_-]mat/ { print $2 }' \
    | sort -u \
    | xargs -r docker rmi -f || true

  # Also catch images only known by ID from dangling/local builds named module_o_mat-web
  docker images --format '{{.Repository}} {{.ID}}' \
    | awk '$1 ~ /^module_o_mat/ || $1 ~ /^module-o-mat/ { print $2 }' \
    | sort -u \
    | xargs -r docker rmi -f || true

  echo "→ Removing matching volumes"
  docker volume ls -q | awk '/module_o_mat|module-o-mat/ { print }' | xargs -r docker volume rm -f || true

  echo "→ Pruning dangling images"
  docker image prune -f || true
fi

echo "→ Removing source directories"
for d in "${DIRS[@]}"; do
  if [[ -e "$d" ]]; then
    echo "  rm -rf $d"
    rm -rf "$d"
  fi
done

echo
echo "Done. Host is clean of the local module-o-mat deploy."
echo "Next: set up GHCR pull under /opt/module-o-mat (compose + .env only)."
