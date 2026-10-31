#!/usr/bin/env python3
"""Move Trello In Progress cards to Done only when linked GitHub PRs are merged.

No dependencies outside the Python standard library.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

PR_URL = re.compile(r"https://github\.com/iosdevbyul/([A-Za-z0-9_.-]+)/pull/(\d+)(?!\d)", re.I)
GITHUB_API = "https://api.github.com"
TRELLO_API = "https://api.trello.com/1"


def linked_prs(text: str) -> set[tuple[str, int]]:
    return {(repo, int(number)) for repo, number in PR_URL.findall(text or "")}


def is_complete(merged_states: list[bool]) -> bool:
    return bool(merged_states) and all(merged_states)


def request_json(url: str, token: str | None = None, method: str = "GET",
                 params: dict | None = None) -> object:
    if params:
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
    headers = {"Accept": "application/vnd.github+json",
               "User-Agent": "TrisGithubTrelloSync/1.0"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
        headers["X-GitHub-Api-Version"] = "2022-11-28"
    request = urllib.request.Request(url, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=25) as response:
        return json.load(response)


def trello_request(endpoint: str, key: str, token: str,
                   method: str = "GET", params: dict | None = None) -> object:
    query = {"key": key, "token": token}
    query.update(params or {})
    return request_json(f"{TRELLO_API}{endpoint}", method=method, params=query)


def github_pr_merged(repo: str, number: int, github_token: str) -> bool:
    url = f"{GITHUB_API}/repos/iosdevbyul/{repo}/pulls/{number}"
    data = request_json(url, token=github_token)
    return data.get("merged") is True


def execute(board_id: str, github_token: str, trello_key: str,
            trello_token: str, dry_run: bool = False) -> dict:
    lists = trello_request(f"/boards/{board_id}/lists", trello_key, trello_token,
                           params={"fields": "name", "filter": "open"})
    progress = [item for item in lists if item["name"] == "In Progress"]
    done = [item for item in lists if item["name"] == "Done"]
    if len(progress) != 1 or len(done) != 1:
        raise RuntimeError("Expected exactly one open 'In Progress' and 'Done' list")

    cards = trello_request(f"/lists/{progress[0]['id']}/cards", trello_key,
                           trello_token, params={"fields": "name,desc,url", "limit": 1000})
    if len(cards) >= 1000:
        raise RuntimeError("In Progress contains >=1000 cards; refusing an incomplete scan")

    cache: dict[tuple[str, int], bool] = {}
    report = {"scanned": len(cards), "linked": 0, "moved": [], "skipped": []}
    for card in cards:
        references = linked_prs(card.get("desc", "") + "\n" + card.get("name", ""))
        if not references:
            continue
        report["linked"] += 1
        try:
            # Any unmerged PR linked from the card blocks moving it.
            states = []
            for reference in sorted(references):
                if reference not in cache:
                    cache[reference] = github_pr_merged(*reference, github_token)
                states.append(cache[reference])
        except (urllib.error.HTTPError, urllib.error.URLError, ValueError) as error:
            report["skipped"].append({"card": card["name"], "reason": "PR lookup failed"})
            print(f"PR lookup failed for {card['id']}: {error.__class__.__name__}",
                  file=sys.stderr)
            continue

        if not is_complete(states):
            report["skipped"].append({"card": card["name"], "reason": "PR not merged"})
            continue

        if not dry_run:
            trello_request(f"/cards/{card['id']}", trello_key, trello_token,
                           method="PUT", params={"idList": done[0]["id"]})
        report["moved"].append({"card": card["name"],
                                "mode": "dry-run" if dry_run else "moved",
                                "url": card.get("url")})
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    env_names = ("GH_CROSS_REPO_TOKEN", "TRELLO_API_KEY",
                 "TRELLO_API_TOKEN", "TRELLO_BOARD_ID")
    missing = [name for name in env_names if not os.getenv(name)]
    if missing:
        print("Missing environment variables: " + ", ".join(missing), file=sys.stderr)
        return 2
    try:
        report = execute(
            board_id=os.environ["TRELLO_BOARD_ID"],
            github_token=os.environ["GH_CROSS_REPO_TOKEN"],
            trello_key=os.environ["TRELLO_API_KEY"],
            trello_token=os.environ["TRELLO_API_TOKEN"],
            dry_run=args.dry_run)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except (urllib.error.HTTPError, urllib.error.URLError, RuntimeError) as error:
        print(f"Sync failed: {error.__class__.__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
