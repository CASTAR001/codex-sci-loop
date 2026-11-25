---
name: research-verification
description: "Use when deriving or checking a mathematical or scientific conclusion, especially when assumptions, approximations or limits of validity matter. Also use for testing claims against numerical or empirical evidence. Routine arithmetic and text editing need no special checks."
---

# Research verification

Start from the particular claim. Identify the assumptions and range where it should hold, what observation would contradict it, and how much error is acceptable. For a short calculation, the check and its result can live in the answer. For a continuing investigation, keep the applicable conditions in the task contract and reference the original data, derivation or experiment.

Choose a check with a different failure mode from the implementation. For instance, a solver claiming second-order accuracy can be tested against a known exact solution on successively finer grids. Record the grid sizes, errors and observed order. For a derivation, a limiting case, a dimensional inconsistency or an independent derivation may be more informative. Match the check to the claim.

Use the same project checkpoint as other tasks when persistence helps. Declare the check command and its inputs, including relevant data, parameters, seed and implementation. Keep hypotheses as attributed notes. Preserve a meaningful negative result with its conditions and an evidence path. Identify which measured result supports each conclusion and what remains unresolved.

Use independent review when assumptions, derivation or test sufficiency remain in question. Give an authorized reviewer the claim, original evidence and the subject from `show --for-review --full`. Record the report against that subject. Report the remaining uncertainty if evidence is insufficient. A process exit code establishes only the assertion exercised by that process.
