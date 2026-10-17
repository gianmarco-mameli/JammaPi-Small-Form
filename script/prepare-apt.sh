#!/bin/bash

set -e

os_release=${1:-/etc/os-release}
apt_directory=${2:-/etc/apt}

. "$os_release"
if [ "${ID:-}" != "raspbian" ]; then
    exit 0
fi
if [ "${VERSION_CODENAME:-}" != "buster" ] && [ "${VERSION_ID:-}" != "10" ]; then
    exit 0
fi

if [ ! -d "$apt_directory" ]; then
    echo "ERRORE: Directory APT mancante: $apt_directory" >&2
    exit 1
fi

temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT

for file in "$apt_directory/sources.list" "$apt_directory"/sources.list.d/*.list; do
    [ -e "$file" ] || continue
    awk '
    /^[ \t]*deb(-src)?[ \t]+/ {
        if ($0 ~ /^[ \t]*deb(-src)?[ \t]+(\[[^]]*\][ \t]+)?https?:\/\/(raspbian\.raspberrypi\.org|mirrordirector\.raspbian\.org|archive\.raspbian\.org)\/raspbian\/?[ \t]+buster[ \t]+/) {
            sub(/https?:\/\/[^ \t]+/, "https://legacy.raspbian.org/raspbian/")
        }
    }
    { print }
    ' "$file" > "$temporary"

    if cmp -s "$temporary" "$file"; then
        continue
    else
        status=$?
        if [ "$status" -ne 1 ]; then
            echo "ERRORE: Impossibile confrontare $file" >&2
            exit "$status"
        fi
    fi
    if [ ! -e "$file.jammapi.bak" ] && [ ! -L "$file.jammapi.bak" ]; then
        cp -p "$file" "$file.jammapi.bak"
    fi
    printf 'Aggiorno repository Raspbian Buster: %s\n' "$file"
    cat "$temporary" > "$file"
done
