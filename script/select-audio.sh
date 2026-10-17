#!/bin/bash

set -e

output=${1:?Missing audio output}
config=${2:-/etc/asound.conf}
cards=${3:-/proc/asound/cards}
case "$output" in
    HDMI|JAMMA) ;;
    *) echo "Invalid audio output: $output" >&2; exit 1 ;;
esac

card=$(awk -v output="$output" '
/^[ \t]*[0-9]+[ \t]+\[/ {
    if ((output == "HDMI" && $0 ~ /HDMI/) ||
        (output == "JAMMA" && $0 ~ /Headphones/)) {
        id = $0
        sub(/^[^[]*\[/, "", id)
        sub(/\].*$/, "", id)
        gsub(/[ \t]/, "", id)
        print id
        exit
    }
}' "$cards")

if [ -z "$card" ]; then
    # Older kernels expose both outputs through a single bcm2835 ALSA card.
    card=$(awk '
    /^[ \t]*[0-9]+[ \t]+\[/ && /bcm2835 ALSA/ {
        id = $0
        sub(/^[^[]*\[/, "", id)
        sub(/\].*$/, "", id)
        gsub(/[ \t]/, "", id)
        print id
        exit
    }' "$cards")
    if [ -z "$card" ]; then
        echo "ERRORE: Uscita audio $output non disponibile. Controllare aplay -l." >&2
        exit 1
    fi
    controls=$(amixer -c "$card" controls)
    if ! grep -Fq "name='PCM Playback Route'" <<< "$controls"; then
        echo "ERRORE: Controllo PCM Playback Route mancante sulla scheda $card." >&2
        exit 1
    fi
    route=1
    [ "$output" != HDMI ] || route=2
    amixer -c "$card" cset "name=PCM Playback Route" "$route"
fi

temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT
awk -v card="$card" '
/^[ \t]*slave\.pcm[ \t]+/ {
    print "  slave.pcm \"plughw:CARD=" card ",DEV=0\""
    pcm = 1
    next
}
/^ctl\.!default[ \t]/ { next }
{ print }
END {
    if (!pcm) exit 1
    print "ctl.!default { type hw card \"" card "\" }"
}' "$config" > "$temporary" || {
    echo "ERRORE: Configurazione ALSA non valida: $config" >&2
    exit 1
}
if cmp -s "$temporary" "$config"; then
    exit 0
else
    status=$?
    if [ "$status" -ne 1 ]; then
        echo "ERRORE: Impossibile confrontare $config" >&2
        exit "$status"
    fi
fi
cat "$temporary" > "$config"
printf 'Uscita audio %s: scheda ALSA %s\n' "$output" "$card"
