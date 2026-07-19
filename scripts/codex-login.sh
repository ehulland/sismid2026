#!/usr/bin/env bash
# Log THIS Codespace into Codex using a class-issued credential.
#
#     bash scripts/codex-login.sh
#
# The server URL is baked in below. You are identified by your GitHub username,
# so the server always hands you back the SAME credential -- restart your
# Codespace, re-run this, and nothing changes. You only need the class passcode
# (the instructor gives it out in class). After it runs, just launch `codex`.
set -euo pipefail

# Class credential server (self-signed TLS, so we use curl -k). Override for testing
# with:  SISMID_CODEX_SERVER=https://host:port bash scripts/codex-login.sh
SERVER="${SISMID_CODEX_SERVER:-https://35.233.251.145:8443}"
SERVER="${SERVER%/}"

# Who you are: your GitHub username in the Codespace (override with arg 1).
# We do NOT fall back to the OS user -- in a Codespace everyone is "codespace",
# which would make the whole class collide on one credential.
WHO="${1:-${GITHUB_USER:-}}"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$CODEX_HOME"; chmod 700 "$CODEX_HOME" 2>/dev/null || true
AUTH="$CODEX_HOME/auth.json"

# Never clobber an auth.json Codex may have already refreshed (OpenAI's guidance).
if [ -s "$AUTH" ]; then
  echo "Codex is already logged in ($AUTH); leaving it in place."
  echo "Start Codex with:  codex"
  exit 0
fi

# Ask for the class passcode (hidden), from the tty if we have one.
if { : < /dev/tty; } 2>/dev/null; then _tty=/dev/tty; else _tty=/dev/stdin; fi
if [ -z "$WHO" ]; then
  printf 'Your name or GitHub username: '
  IFS= read -r WHO < "$_tty"
  [ -n "$WHO" ] || { echo "No name given." >&2; exit 1; }
fi
printf 'Class passcode (input hidden): '
IFS= read -rs PASS < "$_tty"; echo
[ -n "$PASS" ] || { echo "No passcode entered." >&2; exit 1; }

TMP="$(mktemp)"
code="$(curl -fsSk -o "$TMP" -w '%{http_code}' \
          -H "X-Class-Password: $PASS" \
          "$SERVER/claim?who=$WHO" 2>/dev/null || true)"
unset PASS

case "$code" in
  200)
    install -m 600 "$TMP" "$AUTH"; rm -f "$TMP"
    echo "Logged in as '$WHO'. Credential saved to $AUTH"
    echo "Verifying:"; codex login status || true
    echo "Start Codex with:  codex" ;;
  403) rm -f "$TMP"; echo "Rejected: wrong class passcode." >&2; exit 1 ;;
  409) rm -f "$TMP"; echo "No credentials left in the pool. Tell the instructor." >&2; exit 1 ;;
  400) rm -f "$TMP"; echo "Server could not identify you (empty username)." >&2; exit 1 ;;
  000|"") rm -f "$TMP"; echo "Could not reach the server at $SERVER (network/firewall?)." >&2; exit 1 ;;
  *)   rm -f "$TMP"; echo "Server error (HTTP $code)." >&2; exit 1 ;;
esac
