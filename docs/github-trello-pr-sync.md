# Cross-project GitHub → Trello Done synchronization

This automation runs centrally in `iosdevbyul/TrisServerManager`, while checking PR links from **any `iosdevbyul` repository**. Other repositories do not require their own Trello workflow.

## Behavior

Every 15 minutes, GitHub Actions scans the **Tris Work Board** `In Progress` list. A card is moved to `Done` only when:

- Its title or description contains an explicit GitHub pull-request URL: `https://github.com/iosdevbyul/<repository>/pull/<number>`.
- The GitHub API confirms that **every linked PR** is actually merged (`merged: true`), rather than merely closed or CI-passed.
- The card is presently in the `In Progress` list.
- The target board has exactly one open `In Progress` list and one open `Done` list.

The workflow **does not** move `Next` or `Backlog` cards, add cards, rewrite titles, start new development, or close PRs. For cards without a complete PR URL, it makes no guesses; these remain unchanged until linked.

## Initial GitHub setup

Once the PR is reviewed and merged, in **TrisServerManager → Settings → Secrets and variables → Actions**, configure:

**Repository secrets:**

- `GH_CROSS_REPO_TOKEN` — a fine-grained GitHub personal access token scoped to `iosdevbyul` repositories requiring coverage, with read-only Pull requests and Metadata access. Public repos may be accessible without the token, but a private repo requires an appropriately scoped token. Do **not** reuse a full-access token.
- `TRELLO_API_KEY` — your own Trello API key.
- `TRELLO_API_TOKEN` — a Trello token with read access to the board/cards and write access to cards. Treat as secret.

**Repository variable:**

- `TRELLO_BOARD_ID` — the board's Trello ID (not its name). Tris Work Board URL: https://trello.com/b/Jim6N9HN/tris-work-board. The short ID in that URL may be used by Trello's board API if it resolves, or use the full board ID returned by the Trello API.

**Never put API credentials in PRs, source code, CI logs, or Trello cards.** Token creation and GitHub repository settings require your explicit authenticated actions.

## Safe activation

1. CI passes and this PR is manually merged; the scheduled workflow becomes available on `main`.
2. Configure the three secrets and one variable above.
3. Go to **Actions → GitHub to Trello merged PR sync → Run workflow**. Set `dry_run = true` to inspect intended moves without writing Trello.
4. Verify the candidate card titles and PR relationships. Run again with `dry_run = false` after reviewing. Future scheduled runs automatically execute live.
5. Check that merged PR cards move to `Done` while open, closed-but-unmerged, and unlinked cards remain in `In Progress`.

**Operational note:** GitHub may delay scheduled runs. This is periodic synchronization, not instant webhook delivery. Scheduled tasks stop if GitHub disables a repository's scheduled Actions due to inactivity or policy changes.

## Relation to other projects

This process operates on one Trello board, regardless of which `iosdevbyul` repository the linked PR belongs to. All active project cards must use unambiguous canonical GitHub PR URLs. It does not search for or mutate cards on other boards. This is only **automatic completion tracking**; the user still chooses what to build and when.
