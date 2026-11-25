# Working on codex-sci-loop

Use the root README for the supported user workflow. The primary target is native Codex on macOS and Linux, with secondary Windows support. Keep the checkpoint core suitable for everyday tasks. Put scientific methods in the research-verification skill.

The current maintainer context is in `.ai-loop/memory/activeContext.md`. Use the constraints in `.ai-loop/memory/constraint-ledger.md`. Preserve historical runs, audits and experimental results. New native tests use temporary projects and isolated Codex homes.

Validate a change through its public entry point. For contracts and verification run `python3 -B tests/test_sci_loop_checkpoint.py`. For changes to packaging or the Codex interface also run the distribution and native app-server tests described in the README.

Keep source, operator-writable records and independently observed evidence distinguishable. Restrict Git commits to the intended paths. Remote publication and changes to personal Codex installations require separate authorization.
