# godot-lsp

GDScript language server for Claude Code.

Godot's GDScript LSP is **TCP-only** (default port 6005) and lives inside the
editor process. Claude Code spawns language servers over **stdio**. This plugin
bridges the two using the community
[`opencode-godot-lsp`](https://github.com/MasuRii/opencode-godot-lsp).

## Supported extensions

`.gd`, `.gdshader`

## Requirements

- Node.js 14+ (`opencode-godot-lsp` is a Node package)
- `npm install -g opencode-godot-lsp`
- Godot 4.4.1+

**The editor does not need to be open.** If nothing is listening on port 6005,
the bridge launches its own editor instance headlessly and connects to it:

```
godot --editor --headless --display-driver headless --audio-driver Dummy \
      --lsp-port 6005 --path <project>
```

Verified working on Godot 4.7.1 with no `Xvfb` and no `DISPLAY`. If a GUI editor
*is* already running on 6005, the bridge attaches to it instead of spawning a
second one, so the two never conflict.

## Configuration

The manifest contains **no machine-specific paths**, so it syncs across machines
unchanged. It runs `scripts/godot-lsp-launch.sh` via `${CLAUDE_PLUGIN_ROOT}`,
and that wrapper resolves everything at runtime:

- **Project directory** — from `${CLAUDE_PROJECT_DIR}`, which Claude Code
  exports to LSP subprocesses.
- **Godot binary** — discovered by searching, in order: `$GODOT_PATH`; the names
  `godot`, `godot4`, `godot-4`, `Godot` on PATH; then versioned binaries in
  `~/.local/bin`, `/usr/local/bin`, `/usr/bin`, `/opt/godot`, highest version
  first. This matters because Godot ships versioned filenames such as
  `godot4.7.1.x86_64`, which is not on PATH as plain `godot`.

Overrides:

| Variable          | Purpose           | Default |
| ----------------- | ----------------- | ------- |
| `GODOT_PATH`      | Godot binary      | auto-discovered |
| `GODOT_LSP_PORT`  | LSP port          | `6005`  |

If discovery picks the wrong binary, set `GODOT_PATH` rather than editing the
manifest.

## Setup

Run `.claude/scripts/setup-godot-lsp.sh` from the repo root, then restart Claude
Code — LSP servers initialize at startup.

## Verifying

```bash
CLAUDE_PROJECT_DIR=$(pwd) bash \
  .claude/godot-lsp-marketplace/plugins/godot-lsp/scripts/godot-lsp-launch.sh
```

Expect the resolved godot/project/port on stderr, followed by
`Connected to Godot LSP on 127.0.0.1:6005`.

## History

Previously used
[`godot-lsp-stdio-bridge`](https://github.com/code-xhyun/godot-lsp-stdio-bridge),
which worked but required keeping a GUI editor open at all times. Both bridges
return identical results against a running editor; `opencode-godot-lsp` was
adopted for the auto-launch behaviour.
