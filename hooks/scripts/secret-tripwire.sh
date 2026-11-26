#!/usr/bin/env bash
# PostToolUse tripwire: a tool result just carried something shaped like a live
# credential.
#
# No hook can redact a tool result that has already been produced, so this does
# not prevent the leak. What it does is convert a SILENT leak into a known one:
# it tells Claude and the user in the same turn, and appends an incident line so
# there is a record to rotate against later. The value itself is never printed
# or logged - only the pattern name, the tool, and the session.

set -uo pipefail
input=$(cat)

tool=$(jq -r '.tool_name // ""' <<<"$input")
src=$(jq -r '.tool_input.file_path // .tool_input.command // "" | tostring' <<<"$input")

# Image and archive reads are base64 in the transcript; "EAA..." run-ins there
# are false positives, not Meta tokens.
[[ $src =~ \.(jpe?g|png|gif|webp|pdf|zip|tar|gz|woff2?|mp[34]|mov)$ ]] && exit 0

body=$(jq -r '.tool_response // "" | tostring' <<<"$input")
[[ -n $body ]] || exit 0

hits=()
add() { grep -qE -- "$2" <<<"$body" && hits+=("$1"); }

add "Anthropic API key"      'sk-ant-api[0-9]{2}-[A-Za-z0-9_-]{40,}'
add "OpenAI API key"         'sk-(proj|svcacct)-[A-Za-z0-9_-]{40,}'
add "Google API key"         'AIzaSy[A-Za-z0-9_-]{33}'
add "AWS access key id"      'AKIA[0-9A-Z]{16}'
add "GitHub token"           '(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{70,})'
add "Slack token"            'xox[baprs]-[A-Za-z0-9-]{20,}'
add "Meta/WhatsApp token"    'EAA[A-Za-z0-9]{100,}'
add "LangWatch API key"      'ik-lw-[A-Za-z0-9_-]{30,}'
add "ElevenLabs webhook secret" 'wsec_[A-Za-z0-9]{40,}'

# A PEM header on its own is a fixture or a docs snippet, not a leak - this
# test file's own header tripped it. Require real key material behind it, and
# flatten first because grep is line-based and a PEM body is wrapped.
flat=$(tr -d '\r\n' <<<"$body")
grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----[A-Za-z0-9+/=]{100,}' <<<"$flat" \
  && hits+=("private key block")

[[ ${#hits[@]} -eq 0 ]] && exit 0

what=$(IFS=', '; echo "${hits[*]}")
# Overridable so a managed install can point every user at one audit trail.
# mkdir first: under managed settings this runs for users who have never
# started Claude Code, so ~/.claude may not exist yet and the append would
# silently no-op - which is the one failure mode an audit log must not have.
log=${CLAUDE_GUARD_LOG:-$HOME/.claude/secret-leak-incidents.log}
mkdir -p "$(dirname "$log")" 2>/dev/null
printf '%s\tsession=%s\ttool=%s\tpatterns=%s\tsource=%s\n' \
  "$(date -u +%FT%TZ)" "$(jq -r '.session_id // "?"' <<<"$input")" \
  "$tool" "$what" "${src:0:160}" >>"$log" 2>/dev/null

msg="SECRET IN TRANSCRIPT: the $tool result just carried a $what. It cannot be redacted after the fact - treat the credential as exposed and decide on rotation. Logged to $log"

jq -n --arg m "$msg" --arg w "$what" --arg t "$tool" --arg l "$log" '{
  systemMessage: $m,
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: ("A secret-shaped value (" + $w + ") just entered the transcript via the " + $t
      + " tool. Stop and tell the user plainly which credential is exposed and where it came from, so they can decide whether to rotate. Do NOT echo, quote, or re-print the value. Incident logged to " + $l + ".")
  }
}'
exit 0
