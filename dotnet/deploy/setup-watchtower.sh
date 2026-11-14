#!/usr/bin/env bash
# Stellt module-o-mat auf dem Docker-Host auf Autodeployment per Watchtower um.
# Übernimmt Volume/Bind-Mount, Port und Umgebungsvariablen des laufenden Containers.
#
#   bash setup-watchtower.sh [alter-containername] [zielverzeichnis]
#   Standard: module-o-mat-dotnet  ~/module-o-mat
set -euo pipefail

OLD="${1:-module-o-mat-dotnet}"
DIR="${2:-$HOME/module-o-mat}"
IMAGE="ghcr.io/marcel-b/module-o-mat-dotnet:latest"

command -v docker >/dev/null || { echo "docker fehlt"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose (Plugin) fehlt"; exit 1; }

if ! docker inspect "$OLD" >/dev/null 2>&1; then
  echo "Container '$OLD' nicht gefunden. Laufende Container:"
  docker ps --format '  {{.Names}}\t{{.Image}}'
  echo "Aufruf: bash $0 <containername>"
  exit 1
fi

# /data-Mount des alten Containers ermitteln
MTYPE=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Type}}{{end}}{{end}}' "$OLD")
MSRC=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/data"}}{{if eq .Type "volume"}}{{.Name}}{{else}}{{.Source}}{{end}}{{end}}{{end}}' "$OLD")
[ -n "$MSRC" ] || { echo "Kein Mount auf /data bei '$OLD' gefunden, breche ab."; exit 1; }

HOSTPORT=$(docker inspect -f '{{range $p, $b := .HostConfig.PortBindings}}{{if eq $p "8080/tcp"}}{{(index $b 0).HostPort}}{{end}}{{end}}' "$OLD")
HOSTPORT="${HOSTPORT:-5012}"

echo "Alter Container: $OLD"
echo "  /data:  $MTYPE $MSRC"
echo "  Port:   $HOSTPORT -> 8080"
echo "Ziel:     $DIR"
read -rp "Weiter? [j/N] " ok; [[ "$ok" =~ ^[jJyY]$ ]] || exit 0

mkdir -p "$DIR"; cd "$DIR"

# Backup der Daten
BK="$DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ "$MTYPE" = volume ]; then
  docker run --rm -v "$MSRC":/data:ro -v "$DIR":/out alpine tar czf "/out/$(basename "$BK")" -C /data .
else
  tar czf "$BK" -C "$MSRC" .
fi
echo "Backup: $BK"

# Env des alten Containers übernehmen (ohne Docker-/Image-Standardwerte)
if [ ! -f .env ]; then
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$OLD" \
    | grep -E '^(NEXTCLOUD_|ASPNETCORE_|TZ=|LOG)' > .env || true
  echo "PORT=$HOSTPORT" >> .env
  chmod 600 .env
fi

if [ "$MTYPE" = volume ]; then
  VOLLINE="      - $MSRC:/data"
  VOLDEF=$'volumes:\n  '"$MSRC"$':\n    external: true'
else
  VOLLINE="      - $MSRC:/data"
  VOLDEF=""
fi

cat > docker-compose.yml <<YML
services:
  web:
    image: $IMAGE
    container_name: module-o-mat-dotnet
    ports:
      - "\${PORT:-5012}:8080"
    env_file: .env
    environment:
      PORT: "8080"
      DATABASE_PATH: /data/module_o_mat.db
      MANUAL_UPLOADS_DIR: /data/uploads/manuals
    volumes:
$VOLLINE
    labels:
      com.centurylinklabs.watchtower.enable: "true"
    restart: unless-stopped

  watchtower:
    image: containrrr/watchtower:1.7.1
    container_name: module-o-mat-watchtower
    command: --label-enable --cleanup --interval \${WATCHTOWER_INTERVAL:-300}
    environment:
      TZ: Europe/Berlin
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
$VOLDEF
YML

docker compose pull
docker stop "$OLD" && docker rm "$OLD"
docker compose up -d
sleep 5
docker compose ps
curl -fsS -o /dev/null -w "HTTP %{http_code} auf /ui\n" "http://localhost:$HOSTPORT/ui" || echo "App antwortet noch nicht, siehe: docker compose logs web"
echo "Fertig. Watchtower-Log: docker logs -f module-o-mat-watchtower"
