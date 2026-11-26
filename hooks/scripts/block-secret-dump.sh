#!/usr/bin/env bash
# PreToolUse guard: refuse commands whose known failure mode is dumping a whole
# credential-bearing object into the transcript.
#
# Rationale (each rule below comes from a real leak in a Claude Code transcript):
#   - `pm2 jlist` printed every var of a production .env for every process
#   - `node -e` on ecosystem.config.js printed an app block carrying a live API key
#   - a remote `gcloud compute ssh --command=...` re-ran both of those server-side
# No hook can redact a tool result after the fact, so the only real control is
# refusing the call. Each denial names the narrow alternative.
#
# Regexes live in variables: an unquoted `;` or `|` inside [[ =~ ]] is a bash
# parse error, and the script would silently allow everything after it.

set -uo pipefail
input=$(cat)

tool=$(jq -r '.tool_name // ""' <<<"$input")
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

if [[ $tool == "Read" ]]; then
  re_safe='example|sample|template|\.md$'
  re_secret='(^|/)\.env(\.|$)|adminsdk.*\.json$|(^|/)(credentials|service-account[^/]*)\.json$'
  if [[ ! $path =~ $re_safe ]] && [[ $path =~ $re_secret ]]; then
    deny "Reading $path whole would put every credential in it into the transcript, whose retention you do not control. Print only what you need instead: 'cut -d= -f1 <file>' for the key names, or 'grep -c ^SOME_KEY= <file>' to test whether one is set."
  fi
  exit 0
fi

[[ $tool == "Bash" ]] || exit 0
[[ -n $cmd ]] || exit 0

# A heredoc BODY is data, not commands. Without this, writing a commit message
# or a doc that quotes a blocked command is itself blocked - which is exactly
# what happened on the commit that introduced this guard. Stripping the body is
# what keeps the guard documentable.
#
# Two exceptions, or the stripping would be a free bypass: a heredoc fed to a
# shell (`bash <<EOF`, `ssh host <<EOF`) IS commands, and one redirected into a
# *.sh file is commands about to be run. Neither is stripped.
#
# Residual gap, accepted deliberately: text written into a non-.sh file and
# then interpreted some other way is not scanned. This is a deny-list against
# accidental dumps, not a boundary against a determined bypass, and the
# PostToolUse tripwire still fires on the values if they reach a transcript.
q="'\""
re_heredoc="<<-?[[:space:]]*[$q]?([A-Za-z_][A-Za-z0-9_]*)"
re_exec_heredoc="(^|[[:space:]]|[;&|(])(ba|z|k|da)?sh([[:space:]]|$)|ssh[[:space:]]|\.sh([[:space:]]|$)"

strip_heredoc_bodies() {
  local line delim="" trimmed out=""
  while IFS= read -r line; do
    if [[ -n $delim ]]; then
      trimmed=${line#"${line%%[![:space:]]*}"}
      [[ $trimmed == "$delim" ]] && delim=""
      continue
    fi
    out+="$line"$'\n'
    # The exec check runs FIRST: every [[ =~ ]] overwrites BASH_REMATCH, so a
    # second test between the match and the capture silently empties it, and an
    # empty delimiter means nothing is ever stripped.
    if [[ ! $line =~ $re_exec_heredoc ]] && [[ $line =~ $re_heredoc ]]; then
      delim=${BASH_REMATCH[1]}
    fi
  done <<<"$1"
  printf '%s' "$out"
}

scan=$(strip_heredoc_bodies "$cmd")

# Collapse newlines so a wrapped --command= string matches the same way, and so
# a remote command inside `gcloud compute ssh --command=...` is scanned too.
flat=$(tr '\n' ' ' <<<"$scan" | tr -s ' ')

re_pm2='pm2[[:space:]]+(jlist|env|show|describe)'
if [[ $flat =~ $re_pm2 ]]; then
  deny "pm2 jlist/env/show/describe print each process's full pm2_env, which is every var from the app's .env (this has leaked a whole production env). Use 'pm2 status' for health and the per-app PID, 'ls -la <dist-dir>' for build time, or 'sudo cat /proc/<pid>/environ | tr \\0 \\n | grep ONE_VAR' when you genuinely need one value."
fi

re_bareenv='(^|[;&|]|^[[:space:]]*)[[:space:]]*(printenv|env)[[:space:]]*($|[;&|])'
if [[ $flat =~ $re_bareenv ]]; then
  deny "A bare 'env'/'printenv' dumps the whole environment into the transcript. Filter it before it gets there: 'printenv | grep -c ^SOME_KEY=' for a presence test, or 'printenv | cut -d= -f1' for names only."
fi

re_environ='/proc/[^[:space:]]*/environ'
re_filtered='grep|cut|awk[[:space:]]+-F'
if [[ $flat =~ $re_environ ]] && [[ ! $flat =~ $re_filtered ]]; then
  deny "Reading /proc/<pid>/environ unfiltered dumps the live process's whole environment. Append '| tr \\0 \\n | grep ONE_VAR' so only the var you need crosses into the transcript."
fi

re_procenv='(JSON\.stringify|console\.log|pprint|print)[^;]{0,40}process\.env([^.A-Za-z_]|$)'
if [[ $flat =~ $re_procenv ]]; then
  deny "Printing process.env as an object puts every var in the transcript. Print the single field you need, or 'Object.keys(process.env)' if you only need the shape."
fi

re_eco='ecosystem(\.dev)?\.config\.js'
re_evalnode='(node|npx|ts-node|tsx)[[:space:]]+(-e|--eval)'
# Dangerous only when the eval actually serialises a block or touches .env;
# `Object.keys` anywhere is the explicit shape-only escape hatch.
re_ecodump='JSON\.stringify|\.env([^a-zA-Z]|$)'
re_ecosafe='Object\.keys|REDACT|redact'
if [[ $flat =~ $re_eco ]] && [[ $flat =~ $re_evalnode ]] \
   && [[ $flat =~ $re_ecodump ]] && [[ ! $flat =~ $re_ecosafe ]]; then
  deny "A PM2 app block carries an 'env' object sourced from the local .env; stringifying it whole leaks live keys (this has printed a live API key). Print 'Object.keys(app.env)' for the shape, or one named field."
fi

re_gsecret='gcloud[[:space:]]+secrets[[:space:]]+versions[[:space:]]+access'
if [[ $flat =~ $re_gsecret ]]; then
  deny "'gcloud secrets versions access' prints the secret value to stdout and into the transcript. To check a secret exists or changed use 'gcloud secrets versions list <name>'; to load one for a process, pipe it into the process rather than to the terminal."
fi

re_kube='kubectl[[:space:]]+get[[:space:]]+secret'
re_kubefmt='-o[[:space:]]*(yaml|json)'
if [[ $flat =~ $re_kube ]] && [[ $flat =~ $re_kubefmt ]]; then
  deny "'kubectl get secret -o yaml/json' prints every value base64-encoded, which is encoding and not redaction. Use 'kubectl get secret <name>' for the key list."
fi

re_docker='docker[[:space:]]+inspect'
re_dockerfmt='--format|-f[[:space:]]'
if [[ $flat =~ $re_docker ]] && [[ ! $flat =~ $re_dockerfmt ]]; then
  deny "An unformatted 'docker inspect' includes the container's full Env array. Use '--format' to pull only the field you need."
fi

# .env reads: allowed only in a form that cannot print a value.
re_envfile='\.env($|[^a-zA-Z])'
re_envsafefile='example|sample|template'
re_printer='(cat|head|tail|less|more|strings|awk)[[:space:]]|sed[[:space:]]+-n'
re_redacted='cut[[:space:]]+-d|grep[[:space:]]+-[a-zA-Z]*[clq]|REDACT|redact|=<|s/=\.\*/'
if [[ $flat =~ $re_envfile ]] && [[ ! $flat =~ $re_envsafefile ]] \
   && [[ $flat =~ $re_printer ]] && [[ ! $flat =~ $re_redacted ]]; then
  deny "Printing a .env file whole puts every credential in it into the transcript. Key names only: 'cut -d= -f1 <file>'. Presence test: 'grep -c ^SOME_KEY= <file>'. Masked values: sed 's/=.*/=<redacted>/' <file>."
fi

exit 0
