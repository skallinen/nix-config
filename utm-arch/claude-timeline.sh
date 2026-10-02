#!/usr/bin/env bash
# claude-timeline: Claude Code hook that appends one line per event to
# ~/.claude/timeline.log, so Sami and Claude can later tell when things happened
# (Sami, 2026-09-30, after a timer and a start time were both misremembered).
# Line: date time, session id (8 chars), project folder, event, short summary.
# On UserPromptSubmit it also tells the model the current local time.
in=$(cat)
field() { jq -r "$1 // empty" <<<"$in" 2>/dev/null; }
ts=$(date '+%Y-%m-%d %H:%M:%S')
sid=$(field .session_id | cut -c1-8)
cwd=$(basename "$(field .cwd)")
ev=$(field .hook_event_name)
case "$ev" in
  UserPromptSubmit) what=$(field .prompt) ;;
  PreToolUse) what="$(field .tool_name): $(field '(.tool_input.description // .tool_input.command // .tool_input.file_path // .tool_input.message // .tool_input.prompt // .tool_input.query | tostring)')" ;;
  Notification) what=$(field .message) ;;
  SubagentStop) what=$(field .agent_type) ;;
  SessionStart) what=$(field .source) ;;
  *) what="" ;;
esac
what=$(printf '%s' "$what" | tr '\n\t\r' '   ' | cut -c1-140)
printf '%s %-8s %-12s %-16s %s\n' "$ts" "${sid:--}" "${cwd:--}" "${ev:--}" "$what" >> "$HOME/.claude/timeline.log"
if [ "$ev" = UserPromptSubmit ]; then
  # Also the latest Claude usage line from the claude-window monitor (assistant repo,
  # bin/claude-window.clj), without its ccusage tail, so the model sees the 5 h and weekly
  # limits with every prompt (Sami, 2026-10-02: "a script that sends the latest here").
  ctx="Local time now: $(date '+%a %Y-%m-%d %H:%M %Z')"
  usage=$(tail -n 1 "$HOME/.local/state/claude-window.log" 2>/dev/null | sed 's/  *| *ccusage.*//')
  [ -n "$usage" ] && ctx="$ctx. Claude usage at $usage"
  jq -cn --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
fi
exit 0
