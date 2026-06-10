# Claude Code Global Rules

## Language

- Always respond in Japanese

## Git

- Commit messages must always be written in English
- Use Conventional Commits format (e.g. `feat:`, `fix:`, `refactor:`)
- NEVER commit unless the user explicitly instructs you to

## Design

- Follow the Unix philosophy (do one thing well, compose small tools, keep it simple)

## Tools

- **Code search**: prefer semble (`mcp__semble__search` / `mcp__semble__find_related`) over Grep/Glob/Read for understanding how code works.
- **Web fetch**: use WebFetch **first** (lightweight, summarized — faster and cheaper for most sites). **Only if it fails** (403 / blocked / empty / JS-required), fall back to Obscura (`~/.local/bin/obscura`, a Rust headless browser with V8): `obscura fetch <url> --eval "..."`, `obscura serve` (CDP), or the obscura MCP. Obscura is the "second arrow" for AI-blocked / JS-heavy pages, not the default. Install via `~/.dotfiles/bin/install-apps`.
- **Browser E2E tests**: Obscura's CDP lacks request interception (`page.route`) and title reporting, so use **Chromium + Playwright** for automated E2E instead. (Obscura is for scraping / interactive checks, not assertion-driven E2E.)
