#!/usr/bin/env bash
# Claude Code status line
#
# Layout (single line, solid dark-slate background):
#   Opus 4.7 (1M context):high:6%   smartcuts/workspace/crm-domain-modeling[branch]   (U:M:S)

input=$(cat)

# ── ANSI helpers ─────────────────────────────────────────────────────
bg=$'\033[48;2;40;46;64m'
fg=$'\033[38;2;210;215;230m'
fg_warn=$'\033[38;2;255;200;100m'
fg_alert=$'\033[38;2;255;110;100m'
fg_muted=$'\033[38;2;150;160;180m'
# Git status colors
fg_untracked=$'\033[38;2;255;110;100m'   # red — new files not yet tracked
fg_unstaged=$'\033[38;2;255;200;100m'    # yellow — modified, not staged
fg_staged=$'\033[38;2;130;220;140m'      # green — staged, ready to commit
reset=$'\033[0m'
el=$'\033[K'

# ── Gather data ───────────────────────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // ""')
effort=$(echo "$input"     | jq -r '.effort.level // empty')
used=$(echo "$input"       | jq -r '.context_window.used_percentage // empty')

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
# Strip ~/Projects/ prefix if present; otherwise collapse $HOME to ~
if [[ "$dir" == "$HOME/Projects/"* ]]; then
  dir="${dir#$HOME/Projects/}"
else
  dir="${dir/#$HOME/\~}"
fi

git_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
branch=""
untracked=0
unstaged=0
staged=0
has_git=0
if [ -n "$git_dir" ] && [ -e "$git_dir/.git" ]; then
  has_git=1
  branch=$(git -C "$git_dir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  # Counts from porcelain v1: XY <path>
  # X = staged, Y = unstaged. "??" = untracked.
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    xy="${line:0:2}"
    if [ "$xy" = "??" ]; then
      untracked=$((untracked + 1))
    else
      x="${xy:0:1}"
      y="${xy:1:1}"
      [ "$x" != " " ] && [ "$x" != "?" ] && staged=$((staged + 1))
      [ "$y" != " " ] && [ "$y" != "?" ] && unstaged=$((unstaged + 1))
    fi
  done < <(git -C "$git_dir" --no-optional-locks status --porcelain 2>/dev/null)
fi

# ── Segment 1: MODEL ─────────────────────────────────────────────────
model_label="${model_name#Claude }"
[ -n "$effort" ] && model_label="${model_label}:${effort}"
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  ctx_color="$fg"
  if   [ "$used_int" -ge 80 ]; then ctx_color="$fg_alert"
  elif [ "$used_int" -ge 50 ]; then ctx_color="$fg_warn"
  fi
  model_label="${model_label}:${ctx_color}${used_int}%${fg}"
fi

# ── Segment 2: CWD + branch ──────────────────────────────────────────
cwd_label="$dir"
if [ -n "$branch" ]; then
  # Truncate long branch names
  if [ "${#branch}" -gt 14 ]; then
    branch_display="${branch:0:11}..."
  else
    branch_display="$branch"
  fi
  cwd_label="${cwd_label}${fg_muted}[${branch_display}]${fg}"
fi

# ── Segment 3: GIT counts ────────────────────────────────────────────
counts_label=""
if [ "$has_git" = "1" ]; then
  counts_label="(${fg_untracked}${untracked}${fg}:${fg_unstaged}${unstaged}${fg}:${fg_staged}${staged}${fg})"
fi

# ── Segment 4: time since Claude's last message ──────────────────────
# Only ticks while idle if settings.json sets statusLine.refreshInterval.
idle_label=""
tp=$(echo "$input" | jq -r '.transcript_path // empty')
if [ -f "$tp" ]; then
  # Last assistant line in the transcript JSONL (top-level "type":"assistant").
  ts=$(grep '"type":"assistant"' "$tp" | tail -1 | jq -r '.timestamp // empty')
  if [ -n "$ts" ]; then
    # timestamp is ISO-8601 UTC; parse as UTC so the epoch diff is TZ-safe.
    last=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${ts:0:19}" +%s 2>/dev/null)
    if [ -n "$last" ]; then
      e=$(( $(date +%s) - last ))
      [ "$e" -lt 0 ] && e=0
      if   [ "$e" -lt 60 ];   then et="${e}s"
      elif [ "$e" -lt 3600 ]; then et="$((e/60))m$((e%60))s"
      else                         et="$((e/3600))h$(((e%3600)/60))m"
      fi
      idle_label="${fg_muted}⏱ ${et}${fg}"
    fi
  fi
fi

# ── Assemble & render ────────────────────────────────────────────────
sep="   "
line="${bg}${fg} ${model_label}${sep}${cwd_label}"
[ -n "$counts_label" ] && line="${line}${sep}${counts_label}"
[ -n "$idle_label" ] && line="${line}${sep}${idle_label}"
line="${line}${bg}${el}${reset}"

printf '%s\n' "$line"
