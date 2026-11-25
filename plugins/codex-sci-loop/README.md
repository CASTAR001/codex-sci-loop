# Codex Task Checkpoints

Use `task-checkpoint` to save a request, decisions and the next action in the task's own folder. Resume it later with `show`. For a tracking-only task, `close` records an operator-reported end once the pending action is clear.

The Python 3.9+ CLI is `scripts/checkpoint.py`. Run it from the task folder using the absolute script path. Git projects use the worktree root. For a verifiable deliverable, declare a command, run `verify` and use `finish` to check the agreed evidence. An ordinary folder requires explicit `--input` files for verification or review.

Use `research-verification` when evaluating a scientific claim, such as whether a numerical method has the predicted order of accuracy. Scientific checks use the same CLI. No lifecycle hooks are registered.

Older Python phase state can be inspected with `scripts/sci_loop.py resume` or `validate`; both require `--project-root`.
