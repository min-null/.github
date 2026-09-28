# Release flow

This repository follows the MinChat development flow. The canonical process is defined once, at
organization level, in min-null/.github/docs/development-flow.md:

> https://github.com/min-null/.github/blob/main/docs/development-flow.md

Read it completely before creating a branch, opening a pull request, or merging anything.
This file is a local pointer only. It is not a second source of truth, and it does not define
repository-specific process rules.

In short:

- Keep both develop and main.
- Start every feature or fix from the current develop and merge it into develop.
- main accepts only develop -> main release pull requests carrying the elease label.
- Create elease-* tags from main only, after that release pull request is merged.
- A release tag is the only trigger for a production deployment. A branch push, a feature pull
  request, or a manual image build is not a deployment.

Repository-specific runbooks stay with their owner, for example docs/release-flow.md in
minchat-backend and docs/release-process.md in minchat-ops. They describe how to run that
repository, not how the organization branches, merges, and releases.
