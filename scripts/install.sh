#!/usr/bin/env bash
# Instala o quita las barras de estado de Cursor y agy para el usuario actual.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOME_DIR=${HOME:?}
USER_NAME=$(id -un)
STAMP=$(date +%Y%m%d-%H%M%S)

CURSOR_DIR="$HOME_DIR/.config/cursor"
AGY_DIR="$HOME_DIR/.config/agy"
AGY_SETTINGS_DIR="$HOME_DIR/.gemini/antigravity-cli"
CURSOR_CONFIG="$CURSOR_DIR/cli-config.json"
AGY_SETTINGS="$AGY_SETTINGS_DIR/settings.json"
DOT_CURSOR="$HOME_DIR/.cursor"

red=$'\033[0;31m'
green=$'\033[0;32m'
yellow=$'\033[0;33m'
dim=$'\033[2m'
nc=$'\033[0m'

say() { printf '%s\n' "$*"; }
ok() { printf '%s  ✓ %s%s\n' "$green" "$*" "$nc"; }
warn() { printf '%s  ! %s%s\n' "$yellow" "$*" "$nc"; }
bad() { printf '%s  ✗ %s%s\n' "$red" "$*" "$nc" >&2; }

need() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1"
    return 0
  fi
  bad "falta $1"
  return 1
}

maybe() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1"
  else
    warn "no está $1; la barra igual se puede instalar"
  fi
}

write_json() {
  local file=$1
  local filter=$2
  local cmd=$3
  local dir
  dir=$(dirname "$file")
  mkdir -p "$dir"
  local tmp
  tmp=$(mktemp "$dir/.statuslines.XXXXXX")
  if [[ -f $file ]]; then
    if ! jq empty "$file" >/dev/null 2>&1; then
      bad "$file no es JSON válido. No lo reescribo."
      rm -f "$tmp"
      exit 1
    fi
    jq --arg cmd "$cmd" "$filter" "$file" >"$tmp"
    chmod --reference="$file" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  else
    jq -n --arg cmd "$cmd" "$filter" >"$tmp"
    chmod 644 "$tmp"
  fi
  if [[ -f $file ]] && cmp -s "$file" "$tmp"; then
    rm -f "$tmp"
    ok "ya estaba: $file"
    return 0
  fi
  if [[ -f $file ]]; then
    cp -a "$file" "$file.bak-$STAMP"
    ok "respaldo: $file.bak-$STAMP"
  fi
  mv "$tmp" "$file"
  ok "$file"
}

install_one() {
  local src=$1 dest=$2
  mkdir -p "$(dirname "$dest")"
  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    ok "ya estaba: $dest"
    return 0
  fi
  if [[ -f $dest ]]; then
    cp -a "$dest" "$dest.bak-$STAMP"
  fi
  install -m 755 "$src" "$dest"
  ok "$dest"
}

link_cursor_config() {
  [[ -d $DOT_CURSOR ]] || return 0
  local link=$DOT_CURSOR/cli-config.json
  if [[ -L $link ]]; then
    if [[ ! -e $link ]]; then
      ln -sfn "$CURSOR_CONFIG" "$link"
      ok "enlace reparado: $link"
    else
      ok "enlace: $link"
    fi
    return 0
  fi
  if [[ -e $link ]]; then
    warn "$link es un archivo propio. Cursor lee ese, no $CURSOR_CONFIG"
    write_json "$link" '.statusLine = {"type":"command","command":$cmd}' \
      "$CURSOR_DIR/statusline.sh"
    return 0
  fi
  ln -s "$CURSOR_CONFIG" "$link"
  ok "enlace: $link"
}

clear_status() {
  local file=$1
  local needle=$2
  [[ -f $file ]] || return 0
  if ! jq -e --arg n "$needle" '.statusLine.command == $n' "$file" >/dev/null 2>&1; then
    ok "no toco $file"
    return 0
  fi
  local tmp
  tmp=$(mktemp "$(dirname "$file")/.statuslines.XXXXXX")
  jq 'del(.statusLine)' "$file" >"$tmp"
  chmod --reference="$file" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  cp -a "$file" "$file.bak-$STAMP"
  mv "$tmp" "$file"
  ok "quité statusLine de $file"
}

cmd=${1:-}
case $cmd in
  doctor)
    say "Usuario: $USER_NAME"
    say "Casa:    $HOME_DIR"
    printf '%s%s%s\n' "$dim" "────────────────────────────────────────────────────────────────────────────────" "$nc"
    fail=0
    need jq || fail=1
    need bash || fail=1
    maybe git
    maybe secret-tool
    maybe cursor-agent
    maybe agy
    if [[ $fail -ne 0 ]]; then
      exit 1
    fi
    ;;
  install)
    say "Instalo para $USER_NAME en $HOME_DIR"
    command -v jq >/dev/null 2>&1 || { bad "hace falta jq"; exit 1; }
    install_one "$ROOT/scripts/cursor/statusline.sh" "$CURSOR_DIR/statusline.sh"
    install_one "$ROOT/scripts/cursor/statusline-usage.sh" "$CURSOR_DIR/statusline-usage.sh"
    install_one "$ROOT/scripts/agy/statusline.sh" "$AGY_DIR/statusline.sh"
    write_json "$CURSOR_CONFIG" '.statusLine = {"type":"command","command":$cmd}' \
      "$CURSOR_DIR/statusline.sh"
    link_cursor_config
    write_json "$AGY_SETTINGS" \
      '.statusLine = {"type":"command","command":$cmd,"stack_with_default":false}' \
      "$AGY_DIR/statusline.sh"
    say "Abrí una sesión nueva de Cursor y de agy para verlas."
    ;;
  uninstall)
    clear_status "$CURSOR_CONFIG" "$CURSOR_DIR/statusline.sh"
    if [[ -f $DOT_CURSOR/cli-config.json && ! -L $DOT_CURSOR/cli-config.json ]]; then
      clear_status "$DOT_CURSOR/cli-config.json" "$CURSOR_DIR/statusline.sh"
    fi
    clear_status "$AGY_SETTINGS" "$AGY_DIR/statusline.sh"
    for f in "$CURSOR_DIR/statusline.sh" "$CURSOR_DIR/statusline-usage.sh" "$AGY_DIR/statusline.sh"; do
      if [[ -f $f ]]; then
        rm -f "$f"
        ok "borré $f"
      fi
    done
    ;;
  *)
    bad "uso: install.sh doctor|install|uninstall"
    exit 2
    ;;
esac
