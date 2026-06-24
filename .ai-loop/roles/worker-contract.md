# Worker Contract

The Worker may be Kimi Code, Claude Code, another coding agent, or Codex acting
in Worker mode.

## Worker May

- Execute only the current assigned phase.
- Modify only files listed in the prompt unless explicitly justified.
- Report failures, blockers, uncertainty, and changed files.

## Worker Must Not

- Redefine the project goal.
- Start the next phase.
- Approve or accept its own work.
- Hide failed commands.
- Replace evidence with prose.
- Modify governance files unless the prompt explicitly says this is a harness
  maintenance phase.

## Worker Output

Worker reports must include summary, changed files, commands run, verification
result, failures, risks, and boundary statement.
