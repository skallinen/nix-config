#!/bin/bash
# Claude Code status line: context size in tokens and the 5-hour usage window. The
# Mac's ~/.claude/statusline.sh, copied 2026-09-27; installed in the VM by utm-home.nix.
input=$(cat)
pct=$(jq -r '.context_window.used_percentage // 0' <<<"$input")
size=$(jq -r '.context_window.context_window_size // 0' <<<"$input")
ctx_k=$(awk -v p="$pct" -v s="$size" 'BEGIN{printf "%.0f", p*s/100000}')
out="ctx ${ctx_k}k ($(printf %.0f "$pct")%)"
five=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
reset=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
if [ -n "$five" ]; then
  mins=$(( (${reset%.*} - $(date +%s)) / 60 ))
  out="$out | 5h $(printf %.0f "$five")% (resets in $((mins/60))h$((mins%60))m)"
fi
echo "$out"
