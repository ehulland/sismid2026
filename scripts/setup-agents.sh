#!/usr/bin/env bash
# SISMID 2026 - install the AI coding agents.
#
#     bash scripts/setup-agents.sh
#
# Installs the command-line agents only. It does NOT log you in.
# Logging in is a separate, one-line step per agent (see the end of this script).
set -euo pipefail

need_npm() {
  command -v npm >/dev/null 2>&1 && return 0
  echo "npm not found. In a Codespace it is preinstalled; locally, install Node LTS" >&2
  echo "from https://nodejs.org/ and re-run." >&2
  exit 1
}

install_npm_agent() {  # name  npm-package
  echo "==> $1"
  npm install -g "$2" >/dev/null
}

need_npm
echo "Node $(node --version), npm $(npm --version)"
echo

install_npm_agent "OpenAI Codex"          "@openai/codex"
install_npm_agent "Anthropic Claude Code" "@anthropic-ai/claude-code"

# Google Antigravity is the optional backup agent. It is not on npm and ships its
# own installer, so a hiccup here must not abort a script that already installed
# Codex and Claude Code successfully.
echo "==> Google Antigravity (optional backup)"
curl -fsSL https://antigravity.google/cli/install.sh | bash >/dev/null \
  || echo "   (skipped - retry later; Codex and Claude Code are enough for class.)"

echo
echo "Installed:"
printf '  codex   %s\n' "$(codex  --version 2>/dev/null || echo '?')"
printf '  claude  %s\n' "$(claude --version 2>/dev/null || echo '?')"
printf '  agy     %s\n' "$(agy    --version 2>/dev/null || echo 'not installed (optional)')"

cat <<'NEXT'

Agents are installed but NOT logged in. Log in (passcode from the instructor):

  bash   scripts/codex-login.sh       # Codex
  source scripts/claude-login.sh      # Claude Code

Never paste API keys into notebook cells or commit them.
NEXT
