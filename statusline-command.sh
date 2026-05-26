#!/usr/bin/env bash
# Claude Code status line
#
# Layout (single line, solid dark-slate background):
#   Opus 4.7:xhigh   ~/Projects/smartcuts/linkedin-pipeline   Git:main   (Context: 28%)

input=$(cat)

# ── ANSI helpers ─────────────────────────────────────────────────────
# $'...' so each variable holds a real ESC byte. The whole line is emitted
# with a literal `%s` format (see Render), which keeps any '%' in the
# content — e.g. "(Context: 28%)" — safe from printf format interpretation.
# Truecolor background: RGB(40, 46, 64) — dark slate/navy gray
bg=$'\033[48;2;40;46;64m'
# Foreground: light off-white
fg=$'\033[38;2;210;215;230m'
# Muted accent for high context usage
fg_warn=$'\033[38;2;255;200;100m'
fg_alert=$'\033[38;2;255;110;100m'
reset=$'\033[0m'
# Erase-to-end-of-line: fills the rest of the row with the active
# background (background-color-erase), so no terminal-width math is needed.
el=$'\033[K'

# ── Gather data ───────────────────────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // ""')
model_id=$(echo "$input"   | jq -r '.model.id // ""')
effort=$(echo "$input"     | jq -r '.effort.level // empty')
used=$(echo "$input"       | jq -r '.context_window.used_percentage // empty')

dir=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir="${dir/#$HOME/\~}"

git_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')
branch=""
if [ -n "$git_dir" ] && [ -d "$git_dir/.git" ]; then
  branch=$(GIT_DIR="$git_dir/.git" git --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
fi

# ── Segment 1: MODEL ─────────────────────────────────────────────────
# Strip leading "Claude " from display name
model_label="${model_name#Claude }"

# Append :<effort> if present
[ -n "$effort" ] && model_label="${model_label}:${effort}"

# ── Segment 2: CWD ───────────────────────────────────────────────────
cwd_label="$dir"

# ── Segment 3: GIT ───────────────────────────────────────────────────
git_label=""
[ -n "$branch" ] && git_label="Git:${branch}"

# ── Segment 4: CONTEXT ───────────────────────────────────────────────
ctx_label=""
ctx_color="$fg"
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  ctx_label="(Context: ${used_int}%)"
  if   [ "$used_int" -ge 80 ]; then ctx_color="$fg_alert"
  elif [ "$used_int" -ge 50 ]; then ctx_color="$fg_warn"
  fi
fi

# ── Assemble & render ────────────────────────────────────────────────
sep="   "
line="${bg}${fg} ${model_label}${sep}${cwd_label}"
[ -n "$git_label" ] && line="${line}${sep}${git_label}"
[ -n "$ctx_label" ] && line="${line}${sep}${ctx_color}${ctx_label}"
# Re-assert the background, then erase-to-end-of-line: the row is filled
# with the background edge to edge, with no terminal-width detection.
line="${line}${bg}${el}${reset}"

# Emit with a literal '%s' format. The line (data) must NOT go in the
# format string, or the '%' in "(Context: NN%)" is eaten as a printf spec.
printf '%s\n' "$line"
