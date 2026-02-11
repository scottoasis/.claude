# Skill Script Dependency Isolation

Skill scripts MUST NOT depend on the host project's root `node_modules` or system-wide Python packages unless the skill is tightly coupled to that project. Each skill manages its own dependencies in isolation.

## Node.js / TypeScript

Use `pnpm dlx` for CLI tools and one-shot script execution:

```bash
# Run a CLI package without installing it
pnpm dlx tsx scripts/my-script.ts

# Specify extra packages needed at runtime
pnpm dlx --package=zod --package=commander tsx scripts/my-script.ts
```

For skills with their own dependency tree, add a `package.json` inside the skill's `scripts/` directory:

```
.claude/skills/my-skill/
  SKILL.md
  scripts/
    package.json      # skill-local deps
    node_modules/     # gitignored
    my-script.ts
```

Install with: `pnpm install --prefix .claude/skills/my-skill/scripts`

## Python

Use `uv run` for isolated script execution with inline deps:

```bash
# Inline dependency specification
uv run --with requests --with pandas scripts/my-script.py

# With a requirements file
uv run --requirements .claude/skills/my-skill/scripts/requirements.txt scripts/my-script.py
```

For skills with their own venv:

```
.claude/skills/my-skill/
  SKILL.md
  scripts/
    requirements.txt  # pinned deps
    .venv/            # gitignored
    my-script.py
```

Create with: `uv venv .claude/skills/my-skill/scripts/.venv && uv pip install -r .claude/skills/my-skill/scripts/requirements.txt`

## Quick reference

| Runtime    | Isolated one-shot                              | Skill-local deps                                          |
| ---------- | ---------------------------------------------- | --------------------------------------------------------- |
| **Node/TS** | `pnpm dlx --package=dep tsx script.ts`         | `package.json` in `scripts/` + `pnpm install --prefix`   |
| **Python** | `uv run --with dep script.py`                  | `requirements.txt` in `scripts/` + `uv venv`             |

## Rules

1. **Never add skill-only deps to the host project's `package.json`** — if only a skill needs it, isolate it
2. **Tightly-coupled skills are exempt** — e.g., `debug-trace` using the project's `langfuse-client` is fine
3. **Pin versions** in skill-local `package.json` / `requirements.txt` for reproducibility
4. **Gitignore** skill-local `node_modules/` and `.venv/` directories
