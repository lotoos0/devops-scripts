#!/usr/bin/env bash
# git-ssh-doctor.sh — sprawdza i ogarnia push na GitHub przez SSH
# Usage:
#   ./git-ssh-doctor.sh           # interaktywnie naprawi
#   DRY_RUN=1 ./git-ssh-doctor.sh # pokaże co by zrobił

set -euo pipefail

GITHUB_HOST="github.com"
DEFAULT_KEY="${HOME}/.ssh/id_ed25519"
DRY=${DRY_RUN:-0}

run() {
  if [[ "$DRY" == "1" ]]; then
    echo "[DRY] $*"
  else
    eval "$@"
  fi
}

msg() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
ok() { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERR ]\033[0m $*"; }

require_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    err "To nie wygląda na repo Git. Wejdź do katalogu repo."
    exit 1
  }
}

ensure_ssh_key() {
  if [[ -f "${DEFAULT_KEY}" && -f "${DEFAULT_KEY}.pub" ]]; then
    ok "Znaleziono klucz SSH: ${DEFAULT_KEY}"
  else
    warn "Brak domyślnego klucza ${DEFAULT_KEY}. Tworzę nowy (bez passphrase dla wygody)."
    run "ssh-keygen -t ed25519 -C \"$(git config user.email 2>/dev/null || echo user@local)\" -f \"${DEFAULT_KEY}\" -N ''"
    ok "Nowy klucz wygenerowany: ${DEFAULT_KEY}"
    warn "Pamiętaj, aby dodać publiczny klucz do GitHub (Settings → SSH and GPG keys)."
    echo "---------- PUB KEY ----------"
    cat "${DEFAULT_KEY}.pub"
    echo "-----------------------------"
  fi
}

ensure_ssh_config() {
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  local cfg=~/.ssh/config
  if grep -q "Host ${GITHUB_HOST}" "$cfg" 2>/dev/null; then
    ok "~/.ssh/config ma wpis dla ${GITHUB_HOST}"
  else
    warn "Dodaję wpis dla ${GITHUB_HOST} do ~/.ssh/config"
    run "cat >> \"$cfg\" <<'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
EOF"
    run "chmod 600 \"$cfg\""
    ok "Konfiguracja SSH uzupełniona."
  fi
}

ensure_agent_loaded() {
  # start agent jeśli nie działa
  if ! pgrep -u \"$USER\" ssh-agent >/dev/null 2>&1; then
    warn "ssh-agent nie działa — uruchamiam."
    run 'eval "$(ssh-agent -s)"'
  else
    ok "ssh-agent działa."
  fi
  # dodaj klucz jeśli niezaładowany
  if ssh-add -l 2>/dev/null | grep -q "no identities"; then
    warn "Brak kluczy w ssh-agent — dodaję ${DEFAULT_KEY}"
    run "ssh-add \"${DEFAULT_KEY}\""
  else
    ok "ssh-agent ma załadowane klucze."
  fi
}

test_github_ssh() {
  msg "Test połączenia z GitHub przez SSH…"
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    ok "GitHub rozpoznaje Twój klucz."
  else
    warn "GitHub nie potwierdził autoryzacji. Upewnij się, że publiczny klucz jest dodany w GitHub → Settings → SSH and GPG keys."
  fi
}

fix_remote_to_ssh() {
  require_git_repo
  local current
  current="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    err "Brak zdalnego 'origin'. Ustaw go ręcznie: git remote add origin git@github.com:USER/REPO.git"
    return
  fi
  msg "Obecny origin: $current"
  if [[ "$current" =~ ^https://github\.com/(.+)/(.+)\.git$ ]]; then
    local user="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    local ssh="git@github.com:${user}/${repo}.git"
    warn "Origin jest HTTPS. Podmieniam na SSH: $ssh"
    run "git remote set-url origin \"$ssh\""
    ok "Origin ustawiony na SSH."
  elif [[ "$current" =~ ^git@github\.com:.+\.git$ ]]; then
    ok "Origin już jest na SSH."
  else
    warn "Origin ma nietypowy format. Nie zmieniam automatycznie."
  fi
}

set_global_insteadof() {
  local val
  val="$(git config --global --get url.\"git@github.com:\".insteadOf || true)"
  if [[ -z "$val" ]]; then
    warn "Ustawiam globalny rewrite: https://github.com → git@github.com:"
    run 'git config --global url."git@github.com:".insteadOf https://github.com/'
    ok "Gotowe — nowe URL-e HTTPS będą automatycznie przepisywane na SSH."
  else
    ok "Globalny rewrite już ustawiony."
  fi
}

ensure_upstream() {
  require_git_repo
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    ok "Branch '$branch' ma ustawiony upstream."
  else
    warn "Branch '$branch' nie ma upstreamu. Ustawiam 'origin/$branch'."
    run "git push -u origin \"$branch\""
    ok "Upstream ustawiony."
  fi
}

main() {
  msg "=== Git SSH Doctor (DRY_RUN=${DRY}) ==="
  ensure_ssh_key
  ensure_ssh_config
  ensure_agent_loaded
  test_github_ssh
  fix_remote_to_ssh
  set_global_insteadof
  msg "— Opcjonalnie ustaw upstream, jeśli to pierwszy push —"
  ensure_upstream || true
  ok "Skończone. Spróbuj teraz: git push (i git pull bez parametrów)."
}

main "$@"
