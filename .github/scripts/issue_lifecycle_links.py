#!/usr/bin/env python3
"""Extract lifecycle issue references from a pull request body."""

from __future__ import annotations

import argparse
import re
import sys


MARKER = re.compile(
    r"(?i)\b(closes|fixes|resolves|fix|close|refs|see|part[ _-]?of)\s+"
    r"(?:\[([^\]]+)\]\(([^)]+)\)|(<[^>]+>)|(\S+))"
)
GITHUB_ISSUE_URL = re.compile(
    r"(?i)https?://github\.com/([a-z0-9_.-]+/[a-z0-9_.-]+)/issues/(\d+)(?:[?#][^\s)]*)?"
)
REPO_ISSUE = re.compile(r"(?i)^([a-z0-9_.-]+/[a-z0-9_.-]+)#(\d+)$")
LOCAL_ISSUE = re.compile(r"(?i)^#(\d+)$")
CLOSING = {"closes", "fixes", "resolves", "fix", "close"}


def extract_links(body: str, current_repo: str, head: str) -> list[tuple[str, int, bool]]:
    refs: dict[tuple[str, int], bool] = {}
    for match in MARKER.finditer(body or ""):
        keyword = re.sub(r"[ _-]+", " ", match.group(1).lower())
        token = match.group(3) or match.group(4) or match.group(5) or match.group(2) or ""
        token = token.rstrip(".,;:")
        parsed = GITHUB_ISSUE_URL.search(token)
        if parsed:
            repo, number = parsed.group(1), int(parsed.group(2))
        else:
            parsed = REPO_ISSUE.fullmatch(token)
            if parsed:
                repo, number = parsed.group(1), int(parsed.group(2))
            else:
                parsed = LOCAL_ISSUE.fullmatch(token)
                if not parsed:
                    continue
                repo, number = current_repo, int(parsed.group(1))
        key = (repo.lower(), number)
        refs[key] = refs.get(key, False) or keyword in CLOSING

    # A linked GitHub issue may be wrapped in Markdown without a closing keyword.
    for match in GITHUB_ISSUE_URL.finditer(body or ""):
        key = (match.group(1).lower(), int(match.group(2)))
        refs.setdefault(key, False)

    if not refs:
        match = re.search(r"issues-(\d+)", head or "", re.IGNORECASE)
        if match:
            refs[(current_repo.lower(), int(match.group(1)))] = True

    return [(repo, number, closing) for (repo, number), closing in sorted(refs.items())]


def should_close_issue(explicit: bool, current_repo: str, target_repo: str, base: str, release: bool) -> bool:
    return explicit or (base == "main" and release and target_repo.lower() != current_repo.lower())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--head", default="")
    parser.add_argument("--base", default="")
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    rows = extract_links(sys.stdin.read(), args.repo, args.head)
    for repo, number, closing in rows:
        should_close = should_close_issue(closing, args.repo, repo, args.base, args.release)
        print(f"{repo}\t{number}\t{'true' if closing else 'false'}\t{'true' if should_close else 'false'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
