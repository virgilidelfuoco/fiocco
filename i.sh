#!/bin/bash
# Installa o aggiorna Brina, il meteo animato sullo sfondo del Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/virgilidelfuoco/fiocco/main/i.sh | bash
#
# Scarica l'ultima versione, controlla che sia firmata "Brina Sviluppo", la mette in Applicazioni e la apre.
# Scaricata così, macOS non la blocca: niente "Apri comunque" da fare a mano.

main() {
  set -e
  # l'app sta nel ramo "app" di questo repository, in parti sotto i 100 MB (il limite di GitHub per un file)
  local BASE="https://raw.githubusercontent.com/virgilidelfuoco/fiocco/app"
  local B=$'\033[1m' N=$'\033[0m'
  echo
  echo "${B}❄️  Brina${N} — il meteo animato sullo sfondo del Mac"
  echo

  if [ "$(uname)" != "Darwin" ]; then
    echo "Brina funziona solo sul Mac."
    return 1
  fi
  local ver major
  ver="$(sw_vers -productVersion)"
  major="${ver%%.*}"
  if [ "$major" -lt 14 ]; then
    echo "Serve macOS 14 Sonoma o più recente: questo Mac ha macOS $ver."
    echo "Si aggiorna da  › Impostazioni di Sistema › Generali › Aggiornamento Software."
    return 1
  fi

  local T
  T="$(mktemp -d)"
  trap 'rm -rf "$T"' EXIT

  local v parts want got p
  v="$(curl -fsSL --retry 3 "$BASE/versione.txt" 2>/dev/null | head -1 || true)"
  parts="$(curl -fsSL --retry 3 "$BASE/parti.txt" 2>/dev/null || true)"
  want="$(curl -fsSL --retry 3 "$BASE/Brina.zip.sha256" 2>/dev/null | head -1 || true)"
  if [ -z "$parts" ] || [ -z "$want" ]; then
    echo "Non riesco a raggiungere GitHub: controlla la connessione e rilancia il comando."
    return 1
  fi
  echo "Scarico Brina ${v} (circa 150 MB)…"
  : > "$T/Brina.zip"
  for p in $parts; do
    if ! curl -fL --progress-bar --retry 3 "$BASE/$p" >> "$T/Brina.zip"; then
      echo "Download non riuscito: controlla la connessione e rilancia il comando."
      return 1
    fi
  done

  echo "Controllo il file…"
  got="$(shasum -a 256 "$T/Brina.zip" | cut -d' ' -f1)"
  if [ "$got" != "$want" ]; then
    echo "Il file scaricato non è completo (forse GitHub sta ancora aggiornando): riprova tra qualche minuto."
    return 1
  fi
  if ! ditto -x -k "$T/Brina.zip" "$T/x" 2>/dev/null || [ ! -d "$T/x/Brina.app" ]; then
    echo "Il file scaricato è rovinato: rilancia il comando."
    return 1
  fi
  if ! codesign --verify --deep --strict "$T/x/Brina.app" 2>/dev/null \
     || ! codesign -dv "$T/x/Brina.app" 2>&1 | grep -q "Authority=Brina Sviluppo"; then
    echo "La firma di Brina non torna: non la installo."
    return 1
  fi

  local DEST="/Applications"
  if [ ! -w "$DEST" ]; then
    DEST="$HOME/Applications"
    mkdir -p "$DEST"
  fi

  if pgrep -x Brina >/dev/null 2>&1; then
    echo "Chiudo la Brina già aperta…"
    pkill -x Brina || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      pgrep -x Brina >/dev/null 2>&1 || break
      sleep 0.5
    done
  fi

  echo "Installo in $DEST…"
  rm -rf "$DEST/Brina.app" 2>/dev/null || true
  if [ -e "$DEST/Brina.app" ]; then
    echo "Non riesco a sostituire la Brina che c'è già in $DEST:"
    echo "trascinala nel Cestino e rilancia il comando."
    return 1
  fi
  ditto "$T/x/Brina.app" "$DEST/Brina.app"
  xattr -dr com.apple.quarantine "$DEST/Brina.app" 2>/dev/null || true

  echo "Apro Brina…"
  open "$DEST/Brina.app"
  echo
  echo "${B}Fatto!${N} Brina vive nella barra dei menu in alto a destra (l'icona del meteo, non nel Dock)."
  echo "Da lì scegli paesaggio e tema. Per aggiornarla basta rilanciare lo stesso comando."
  echo
}

main "$@"
