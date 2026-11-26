#!/usr/bin/env bash
# Disk-space alert for every Claude Code session on this machine.
#
# Wired to SessionStart and PostToolUse(Bash). Silent while the root disk has
# room. Below the thresholds it prints JSON that shows the user a line
# (systemMessage) and tells the model (additionalContext), throttled per session
# so a long run of Bash calls doesn't repeat it every step.
#
# Why it exists: a full disk on a shared dev VM fails in confusing ways (pnpm
# installs half-finish, git writes corrupt, sessions die mid-edit), and every
# extra worktree is a full copy of the repo.
#
# Throttle stamps live in the runtime dir (tmpfs), so they still work when the
# disk itself is full. Override thresholds with DISK_ALERT_WARN_GB / _CRIT_GB.
# Point DISK_ALERT_CLEANER at an executable to start your own throwaway-only
# cleanup in the background when space is low.

WARN_GB=${DISK_ALERT_WARN_GB:-10}
CRIT_GB=${DISK_ALERT_CRIT_GB:-3}
WARN_EVERY_S=3600   # remind at most hourly per session while low
CRIT_EVERY_S=600    # every 10 min per session while critical

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat 2>/dev/null)
session=$(printf '%s' "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null)

# df --output is GNU-only; fall back to POSIX df -Pk on macOS/BSD.
if df --output=avail / >/dev/null 2>&1; then
  read -r avail_kb pcent < <(df --output=avail,pcent -k / | tail -1)
else
  read -r avail_kb pcent < <(df -Pk / | awk 'NR==2 {print $4, $5}')
fi
avail_gb=$(( avail_kb / 1048576 ))
pcent=${pcent%\%}

if   [ "$avail_gb" -lt "$CRIT_GB" ]; then level=CRITICAL; every=$CRIT_EVERY_S
elif [ "$avail_gb" -lt "$WARN_GB" ]; then level=LOW;      every=$WARN_EVERY_S
else exit 0
fi

stamp_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-disk-alert-$(id -u)"
mkdir -p "$stamp_dir" 2>/dev/null
stamp="$stamp_dir/${session}.${level}"
now=$(date +%s)
if [ -f "$stamp" ] && [ $(( now - $(cat "$stamp" 2>/dev/null || echo 0) )) -lt "$every" ]; then
  exit 0
fi
echo "$now" > "$stamp" 2>/dev/null

cleanup_note=""
if [ -n "${DISK_ALERT_CLEANER:-}" ] && [ -x "$DISK_ALERT_CLEANER" ]; then
  setsid nohup "$DISK_ALERT_CLEANER" >/dev/null 2>&1 < /dev/null &
  cleanup_note=" The configured cleanup ($DISK_ALERT_CLEANER) was started in the background."
fi

free_h=$(df -h / | awk 'NR==2 {print $4}')
user_msg="Disk ${level}: ${free_h} free (${pcent}% used).${cleanup_note:+ Cleanup started.}"
model_msg="DISK SPACE ${level}: only ${free_h} free on / (${pcent}% used, warn <${WARN_GB}G, critical <${CRIT_GB}G). Tell the user in your next reply. Avoid new worktrees, package installs and large temp files until space is freed.${cleanup_note} Safe cleanup, biggest first: (1) scratch/temp dirs of ENDED Claude sessions, after confirming no live session uses them; (2) package-manager caches (npm cache clean --force, pnpm store prune); (3) unused editor remote-server builds; (4) OS package cache. Worktrees with unpushed commits, dirty or untracked files are NOT throwaway: list them for the user instead of deleting."

jq -n --arg ev "$event" --arg um "$user_msg" --arg mm "$model_msg" \
  '{systemMessage: $um, hookSpecificOutput: {hookEventName: $ev, additionalContext: $mm}}'
exit 0
