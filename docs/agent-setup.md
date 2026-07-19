# Setting up an AI coding agent

We install the agents **during the course**, on purpose: the point is that you can do
this yourself afterward, on your own laptop or server, not just in our preconfigured
Codespace. This initial environment ships **no agent**, only Node.js so the install is
a single command.

We will use **three** command-line agents in class so you can compare them. They run
right in the browser Codespace (two install with `npm`, one with its own installer):

- **OpenAI Codex CLI**
- **Anthropic Claude Code**
- **Google Antigravity CLI** (`agy`)

## One-step install

From a terminal in your Codespace:

```bash
bash scripts/setup-agents.sh
```

This installs all three CLIs. It does **not** log you in; authentication is a separate
step (below), and it differs per agent: Claude Code uses a shared encrypted token, Codex
uses a per-student credential broker, and Antigravity uses your own free Google login.

## Manual install (what the script does)

```bash
# OpenAI Codex CLI
npm install -g @openai/codex

# Anthropic Claude Code
npm install -g @anthropic-ai/claude-code

# Google Antigravity CLI (not on npm; ships its own installer)
curl -fsSL https://antigravity.google/cli/install.sh | bash
```

Verify:

```bash
codex --version
claude --version
agy --version
```

## Authentication

For **Claude Code** (and any other instructor-provided credential), the class uses a
shared secret that is stored **encrypted** in the repo and unlocked with a **class
passcode** the instructor gives out on the day.

### Students: unlock in one step

From a terminal in your Codespace:

```bash
source scripts/claude-login.sh
```

Enter the class passcode when prompted. This decrypts the shared **Claude Code** token so
`claude` picks it up automatically. (Codex has its own step below; Antigravity uses your
own free Google login.)

- You must use `source` (not `bash scripts/claude-login.sh`), or the variables will not
  stick to your shell.
- You only need to do this **once per Codespace**. The unlock also saves the token to
  your `~/.bashrc`, so new terminals and a Codespace restart stay logged in. (If you
  ever rebuild the container from scratch, run it again.)
- Wrong passcode just fails cleanly; ask the instructor and retry.

Then start the agent **in the terminal**:

```bash
claude --dangerously-skip-permissions
```

Use the terminal, not the VS Code "Claude Code" side panel. In a Codespace the panel
starts before you unlock and cannot see the shared token, so it will show a login
screen; the terminal is the supported path for this class.

That flag lets the agent read, edit, and run commands **without stopping to ask each
time**. We use it on purpose so you see what an autonomous agent actually does, and it
is safe here because your Codespace is a disposable container, not your own machine.
`source scripts/claude-login.sh` already completed Claude Code's first-run setup for you,
so it opens straight to the prompt with no login screen.

### Codex: get your own credential from the class broker

Codex uses a **separate, per-student** credential handed out by a small class server, so
no two students share one login. The server URL is already baked into the script. Once,
in your Codespace:

```bash
bash scripts/codex-login.sh
```

Enter the **class passcode** when prompted. It fetches your own credential into
`~/.codex/auth.json`, then just run:

```bash
codex
```

The server identifies you by your **GitHub username** and remembers which credential is
yours, so if your Codespace restarts (or you make a new one) you get the **same** one
back, never someone else's. If it says the pool is empty or the passcode is wrong, tell
the instructor. The script will not overwrite an existing `~/.codex/auth.json`, so run it
only once per Codespace.

### Antigravity: bring your own free login

Antigravity CLI has a free tier (the "Starter Quota", running Gemini models). Just run
`agy` and sign in with any Google account: it opens a browser tab locally, and in a
remote session (like a Codespace terminal) it prints a URL for you to open. This is also
the **backup** if the shared credential is unavailable.

> This replaces the old Gemini CLI. Google retired the free "Sign in with Google" tier of
> Gemini CLI for individual accounts on **2026-06-18**, before this course, and points
> everyone to Antigravity. `agy` is that successor. (Codex and Claude Code are unaffected;
> they use the shared instructor credential above.)

### Instructor: create / rotate the encrypted secret

Run this on your own machine (it never prints the secret and never writes plaintext):

```bash
# 1. Mint a long-lived Claude Code token (valid ~1 year):
claude setup-token          # copy the CLAUDE_CODE_OAUTH_TOKEN it prints

# 2. Encrypt it under the class passcode:
scripts/secret-encrypt.sh CLAUDE_CODE_OAUTH_TOKEN
#    paste the token, then type the class passcode twice

# 3. Commit the encrypted blob (only the .enc file is safe to commit):
git add secrets/CLAUDE_CODE_OAUTH_TOKEN.enc && git commit -m "Add encrypted agent token"
```

To also share an OpenAI key for Codex, repeat with `scripts/secret-encrypt.sh
OPENAI_API_KEY`. (Codex has no long-lived subscription token like Claude's, so use an
`OPENAI_API_KEY` here.) The env-var **name** you pass is exactly what students receive.

**Encryption details:** AES-256-CBC, PBKDF2-SHA256 at 600k iterations, random salt,
base64 armored. Only `secrets/*.enc` can be committed; `.gitignore` blocks any plaintext
that lands in `secrets/`.

**After the course:** revoke access by rotating the credential at its source (re-run
`claude setup-token` to invalidate the old one, or delete the OpenAI key), so any copies
students kept stop working.

> Golden rule: **credentials never get committed in plaintext and never get pasted into a
> notebook cell.** Only the encrypted `.enc` blob and the spoken passcode leave your hands.

### Instructor: run the Codex credential broker

Codex has no long-lived shareable token, and one ChatGPT `auth.json` shared across the
class hard-fails (concurrent clients trip refresh-token reuse). So generate **one
credential per student** and hand them out with a small server that never gives the same
one to two students.

The broker and its credentials live **outside this repo** (in `~/sismid-creds/`, which is
never committed) because they hold real ChatGPT logins. The scripts there:

```bash
# 1. Generate N device credentials (resumable: re-run after a rate-limit and it
#    skips the ones already saved). Each `codex login` opens a browser to approve.
~/sismid-creds/scripts/gen-creds.sh            # fills auth-01.json .. auth-20.json

# 2. Sanity-check any credential in a clean container before class:
~/sismid-creds/scripts/test-cred.sh all

# 3. Deploy the broker to your always-on host as a systemd service over HTTPS:
CLASS_PASSWORD='your-class-passcode' ~/sismid-creds/server/deploy-vm.sh
```

The broker assigns distinct credentials keyed by **GitHub username** (idempotent: the same
student always gets the same one), gates every request on the single class passcode, and
exposes admin endpoints:

```bash
curl -sk 'https://HOST:8443/status'  -H 'X-Class-Password: PASS'   # who has which
curl -sk 'https://HOST:8443/release?who=USER&pw=PASS' -X POST      # free one back
curl -sk 'https://HOST:8443/reset?pw=PASS'            -X POST      # clear all
```

Keep in mind:

- **Capacity:** 20 device codes from one ChatGPT account is still ONE subscription's rate
  limit shared 20 ways; it does not multiply seats. Fine for bursty use on ChatGPT Pro, it
  will throttle under fully synchronized load. The account may also cap concurrent sessions.
- **Transit:** the broker serves HTTPS with a self-signed cert (clients use `curl -k`), so
  the passcode and credential are encrypted in transit. Take the server down after class
  and rotate the ChatGPT logins afterward.
- **Never commit** the credentials or passcode. `.gitignore` blocks `auth-*.json`,
  `server/creds/`, `state.json`, and `passcode`; the live broker and creds are kept in
  `~/sismid-creds/`, off the repo entirely.

## If you cannot get an agent working

That is fine. Every exercise ships a **pre-filled solution notebook** (the "Plan B"
path) so you can follow along without an agent. You will not be blocked.
