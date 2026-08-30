# codex-sci-loop

`codex-sci-loop` is a project-local, evidence-gated plugin for the native Codex
runtime. It does not replace the Codex agent engine or launch a second worker
runtime. The active Codex thread performs the work; the plugin records phase
state, verification, Git evidence, independent review, and recovery state.

## v1 architecture

- `plugins/codex-sci-loop/`: the 1.0.0 plugin with a Python phase core,
  capability ABI, Codex hook adapter, signed audit protocol, schemas, and six
  skills.
- `loop-standard/`: a PowerShell compatibility toolkit for older projects. It
  is not LumiForge's native agent runtime.
- `.ai-loop/`: this repository's historical control plane and audit evidence.
- `tests/`: provider-free distribution, capability, receipt, and hook tests.

The completion boundary is deliberately fail closed:

1. The host adapter captures the original Goal request before model execution.
2. The executor may submit verifiable claims but cannot accept its own prose.
3. A clean-room native Codex subagent reviews only the canonical audit snapshot
   with `fork_turns=none` and no parent reasoning history.
4. Only a fresh host-issued signed receipt from a protected root can allow
   completion; a Markdown verdict is not authority.
5. After a Codex update, the capability ABI, adapter, runtime artifact, and
   behavior evidence are compared first. Compatible updates continue normally;
   only relevant drift requires recertification or a plugin update.

## Entrypoints

```bash
python3 plugins/codex-sci-loop/scripts/sci_loop.py --help
python3 plugins/codex-sci-loop/scripts/audit_protocol.py --help
python3 plugins/codex-sci-loop/scripts/capability_gate.py --help
```

Bundled skills:

- `loop-goal-bootstrap`
- `loop-supervisor`
- `loop-auditor`
- `loop-recovery`
- `research-loop-orchestrator`
- `independent-completion-auditor`

The final skill is restricted to the isolated reviewer subagent created by the
LumiForge host.

## Provider-free validation

```bash
python3 tests/test_sci_loop_distribution.py
python3 tests/test_sci_loop_capability_abi.py
python3 tests/test_sci_loop_audit_receipt.py
python3 tests/test_sci_loop_codex_hooks.py
bash loop-standard/scripts/Test-PlatformInstall.sh
```

Validate plugin and skill packaging directly:

```bash
python3 ~/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  plugins/codex-sci-loop

for skill in plugins/codex-sci-loop/skills/*; do
  python3 ~/.codex/skills/.system/skill-creator/scripts/quick_validate.py "$skill"
done
```

These checks do not call a real Provider, launch a browser, or install/update
the currently running Codex plugin.

## User-local installation

Linux:

```bash
./install.sh \
  --install-root "$HOME/.codex/loop-harness" \
  --install-plugin \
  --create-shim \
  --create-marketplace \
  --force
```

Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 `
  -InstallRoot C:\path\to\loop-harness `
  -InstallPlugin -CreateShim -CreateMarketplace -Force
```

Installation copies into the explicit destination; it does not silently
replace a running plugin. LumiForge validates and atomically projects a
certified copy into each account-private Codex home instead of loading a
mutable source checkout.

## Compatibility toolkit

Existing projects may continue to use `loop-standard/` for `init`, `start`,
`collect`, `audit-pack`, `resume`, and schema migration. Its generic external
worker interface is retained only for compatibility; the v1 native plugin and
LumiForge Goal mode do not depend on it. New behavior should be added to the
Python plugin core instead of duplicating an agent execution engine.

## Safety

- Never store passwords, tokens, Provider keys, or account files in `.ai-loop`.
- Never load the production plugin directly from a mutable checkout.
- Never accept executor prose as completion evidence.
- Never reuse an audit receipt after protected inputs, workspace evidence, or
  runtime identity changes.
- Installation, remote push, tags, and production activation remain separate
  authorization boundaries.
