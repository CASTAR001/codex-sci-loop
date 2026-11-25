---
name: research-verification
description: "Verify scientific or numerical claims with repeatable checks, or record an independent technical review against a specific task checkpoint and evidence."
---

# Research verification

Choose checks that could disprove the claim. Examples include a dimensional or conservation identity, an analytic limit, grid refinement, and an independently implemented reference. Record the applicable assumptions, tolerance and acceptance rule in the task contract. Preserve input versions, seeds, parameters and the exact check command. Keep referenced data and meaningful negative results in the project.

Use the companion task checkpoint CLI (`../../scripts/checkpoint.py`). Supply `--input` for relevant Git-ignored data. Keep tentative findings under `note --kind hypothesis` and failures or eliminated approaches under `note --kind ruled-out`. A successful execution proves only the assertion actually exercised. Review derivations, assumptions and test coverage separately when they matter.

For an independent review:

1. Run `show --for-review --full` and record `review_subject`. Give an authorized native reviewer the effective contract, exact evidence paths and subject identifier. Use a fresh context when available. Inspect source, original measurements and the derivation directly. Report any independence limitations.
2. Return a report citing files, parameters or reproducible observations for each conclusion, with an overall outcome of `supported`, `rework`, `inconclusive` or `blocked`.
3. Record it with `review --subject <original-digest> --reviewer <declared-identity> --outcome <outcome> --file <file-or-stdin-dash>`. Use stdin or a project control file for the report so writing it does not itself change the subject. A stale digest requires review of the changed evidence.
4. `show` checks freshness. The review records attributed judgment. The native checkpoint supplies no identity attestation or signed acceptance. Repeated agreement between reviewers adds no independent measurement.
