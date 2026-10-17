# Repo Instructions

## Purpose

- This repository is the organization-level container for `min-null`.
- The **process** lives here: a single development flow covering branches, pull requests, release, and deploy.
- Product source code, runtime, contracts, environments, and secrets do not live here.

## Required Reading

- `docs/development-flow.md` is the single canonical process document.
  Read it in full before adding a step to the process or before changing branch,
  release, or gate rules.
- [`minchat-hq/docs/process/feature-pipeline/README.md`](https://github.com/min-null/minchat-hq/blob/main/docs/process/feature-pipeline/README.md)
  is the canonical feature-pipeline: status slots, the readiness rule, and the
  agent self-check. Read it before claiming an issue or starting work.
  An issue is ready when it carries `status:pickable` and no `coordination:blocked`.
  Readiness is **substantive** — description, acceptance criteria, `type:` /
  `area:` / `priority:` — and is enforced by the `readiness-gate` job against
  `scripts/lib/readiness.sh`. `needs:*` and `*:approved` are navigation labels and
  do not block work.
- [`minchat-hq/docs/process/product-owner/README.md`](https://github.com/min-null/minchat-hq/blob/main/docs/process/product-owner/README.md)
  is the standing mandate under which a Product Owner agent selects and directs
  work without per-feature sign-off, and the limits that mandate never covers.
  Read it before making a product decision here.

## Rules

- The process is single and shared across the organization's repositories. A repository adds data, commands, and its own runbooks. It does not invent process rules.
- A new process step is described in `docs/development-flow.md` first, then referenced from the repositories. Do not add process to repositories.
- This document links to source-of-truth in other repositories and does not copy their content.
- Team-facing documentation is kept in Russian; commands, identifiers, paths, and code snippets stay as is.
- Do not commit `.env`, credentials, private keys, production dumps, or local runtime state.

## Verification

- Before merge, verify that new documentation links resolve and do not contradict
  the canonical sources in the owning repositories.
- Before merge, run the shell tests that cover anything you changed:
  `bash scripts/test-lifecycle-extraction.sh` and `bash scripts/test-readiness.sh`.
  A change to a lifecycle rule without its behavioral test is an unfinished change.
- The readiness rule is deliberately free of `jq` and of any clock, so it runs in
  the workflow and in the test on a bare runner. Keep it that way; introducing a
  dependency there makes the rule testable only where that dependency exists.
