# Progress

## Completed In The Native v1 Source Batch

- Promoted the reviewed portable plugin into plugins/codex-sci-loop/.
- Replaced the obsolete plugin distribution with the native Python phase core,
  capability gate, hook adapter, signed audit protocol, schemas, and six
  skills.
- Removed active reviewer-specific prompt/profile/runtime paths and the
  duplicated system-level hook deployment route.
- Kept accepted historical evidence intact while slimming current bootstrap
  memory and documentation.
- Updated user-local Linux and Windows installer paths, marketplace identity,
  readiness reporting, and isolated-install smoke checks.
- Added repository-local tests for distribution/lifecycle, capability ABI,
  signed receipts, and Codex hooks.
- Added phase-029 as the provider-free native v1 verification aggregate.
- Verified that the canonical plugin tree is byte-identical to LumiForge's
  reviewed vendored source.
- Verified that origin/main and the currently installed Codex plugin remain
  unchanged.

## Verification Result

The complete native matrix passed twice: once interactively and once through
the legacy evidence collector to create a durable verify.log. A preceding
preflight stopped before tests because one ignored bytecode cache kept the
retired directory present; only that exact cache and its empty directories
were removed.

No Provider call, browser scenario, service lifecycle action, production
mutation, remote operation, tag, push, or current-plugin installation occurred.

## Pending

- Independent audit and local checkpoint commit in the canonical repository.
- LumiForge upstream metadata update in a separate product phase.
- Later installation into the running Codex, only with explicit authorization.
- Remote publication, tag, and release, only with explicit authorization.
