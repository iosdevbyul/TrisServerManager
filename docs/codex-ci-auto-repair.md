# Cross-repository Codex CI auto-repair

Central reusable workflow: `.github/workflows/reusable-codex-ci-autofix.yml`.

## Contract

- Starts **only** when an existing user-authored PR's `CI` fails. No new feature development or task selection.
- Verifies same-repo PR, owner `iosdevbyul`, base `main`, non-draft, unchanged exact failed SHA.
- Labels `manual-qa` or `no-autofix` prevent repair.
- Codex's only permission is read-only repository access and workspace-local code changes. GitHub token with write access is **not** present in the Codex job.
- Separate publish job checks the patch, blocks workflow/secrets/security files, caps the patch size, and pushes to the **existing PR branch**, never to `main`.
- No more than **two automated repair commits per PR**. An unrecoverable CI failure stays open for user review.
- A new CI run is triggered by the push; existing auto-merge rules may merge the PR on success.

## Required credentials

Each enabled repository needs two Actions **repository secrets**:
- `OPENAI_API_KEY`: a key for OpenAI API usage, with a budget/rate limit; this can incur **separate API charges** from a ChatGPT subscription.
- `AUTOFIX_PUSH_TOKEN`: fine-grained GitHub PAT with Contents read/write on the enabled repositories. This must belong to a trusted account able to push to the user's PR branches. It is used only by the patch-publishing job. Do not paste these tokens in chat or commit them.

Because the repositories are owned by a personal account rather than an organization, repository secrets may need to be configured separately. Never share the OpenAI API key with normal CI build/test steps.

## Enable in a repository

Create a wrapper in `.github/workflows/codex-ci-autofix.yml` with the **exact CI workflow name**:

```yaml
name: Auto Repair Failed CI
on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
permissions:
  contents: read
jobs:
  repair:
    if: ${{ github.event.workflow_run.conclusion == 'failure' && github.event.workflow_run.event == 'pull_request' }}
    uses: iosdevbyul/TrisServerManager/.github/workflows/reusable-codex-ci-autofix.yml@main
    secrets: inherit
```

**Activate the central workflow PR first**, then merge the wrapper PRs. This first version is a pilot: verify repository permissions, GitHub Actions reusable workflow compatibility, model action configuration, and one actual test failure before enabling broadly.

## Safety / cost

- Configure spending limits and monitor token usage in your API account.
- For hardware-dependent tests, keep the PR as Draft or apply `manual-qa`.
- This does **not** automatically start subsequent tasks.
- `workflow_run` must refer to the actual CI workflow name in each repo. Not every project has GitHub Actions or a buildable CI.
- If a token is missing, repairs must fail closed rather than attempt a merge.
