# Current architecture

Version 1.1 targets native Codex on macOS and Linux, with secondary Windows support. The ordinary package exposes task-checkpoint and research-verification and registers zero lifecycle hooks. Project-local contracts, deterministic verification and optional attributed reviews are handled by scripts/checkpoint.py. Codex owns execution, compaction, scheduling and delegation.

The older Python phase tools and PowerShell toolkit remain available to projects using their state formats. Signed receipts require a separately certified host and protected evidence. The LumiForge template lives under adapters/lumiforge/ and is opt-in.

The current behavioral evidence, run conditions and limits are collected in [the native architecture review](../../docs/native-codex-review.md).
