# Repo Instructions

## Purpose

- This repository is the organization-level container for `min-null`.
- The **process** lives here: a single development flow covering branches, pull requests, release, and deploy.
- Product source code, runtime, contracts, environments, and secrets do not live here.

## Required Reading

- `docs/development-flow.md` is the single canonical process document.
  Read it in full before adding a step to the process or before changing branch,
  release, or gate rules.

## Rules

- The process is single and shared across the organization's repositories. A repository adds data, commands, and its own runbooks. It does not invent process rules.
- A new process step is described in `docs/development-flow.md` first, then referenced from the repositories. Do not add process to repositories.
- This document links to source-of-truth in other repositories and does not copy their content.
- Team-facing documentation is kept in Russian; commands, identifiers, paths, and code snippets stay as is.
- Do not commit `.env`, credentials, private keys, production dumps, or local runtime state.

## Verification

- Before merge, verify that new documentation links resolve and do not contradict the canonical sources in the owning repositories.
