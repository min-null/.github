# Release flow

This repository follows the shared MinChat branch contract.

- Keep both `develop` and `main` branches.
- Start every feature or fix from the current `develop`.
- Push work to a feature/fix branch and open a pull request (MR) into `develop`.
- Promote only `develop -> main` through a release pull request (MR) carrying the `release` label.
- Create `release-*` tags only from `main`, after the release MR is merged.
- A release tag is the only trigger for the release deployment pipeline. A branch push, a feature PR, or a manual image build is not a deployment.

For a cross-repository release, use the same release tag in every release-producing repository. The release coordinator must verify that the referenced commits are on `main` before dispatching deployment.
