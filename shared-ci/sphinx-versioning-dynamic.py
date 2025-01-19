"""Module for generating switch.json file."""

#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from packaging.version import Version

ROOT = os.getcwd()
WEBSITE_HOME = os.environ["CI_PAGES_URL"]
DOCS_STABLE_HOME = os.path.join(ROOT, os.environ["DEPLOY_WEBSITE_STABLE_PREFIX"])
DOCS_LATEST = "dev"
DOCS_ROOT = os.path.join(ROOT, "docs")
DOCS_DEST = os.path.join(ROOT, "public")
PROJECT_NAME = os.environ["CI_PROJECT_NAME"]
SWITCHER_JSON_NAME = "switcher.json"
REDIRECTS_NAME = "_redirects"


def format_version_entry(version: str) -> dict[str, str]:
    """Format a single entry of switcher.json, as expected by `pydata-sphinx-theme`."""
    return {
        "url": "/".join((WEBSITE_HOME, version, "")),
        "version": version,
    }


def validate_docs_folder(path: str) -> bool:
    """Check that folder with path specified contains valid documentation."""
    return os.path.isdir(path) and os.path.isfile(os.path.join(path, "index.html"))


def get_stable_versions() -> list[str]:
    """List available versions of the package in the reversed semver order."""
    out: list[str] = []
    if os.path.isdir(DOCS_STABLE_HOME):
        for filename in os.listdir(DOCS_STABLE_HOME):
            if validate_docs_folder(folder := os.path.join(DOCS_STABLE_HOME, filename)):
                out.append(filename)
            else:
                print(
                    f"Folder invalid documentation folder in {DOCS_STABLE_HOME}: {folder}"
                )
    return list(reversed(sorted(out, key=Version)))


if __name__ == "__main__":
    versions = get_stable_versions()

    default_version = None
    for version in versions:
        if not Version(version).is_prerelease:
            default_version = version
            break
    if default_version is None:
        default_version = DOCS_LATEST

    versions.insert(0, DOCS_LATEST)
    contents = [format_version_entry(version) for version in versions]
    print(f"WRITING {SWITCHER_JSON_NAME}:\n")
    print(contents)
    with open(os.path.join(DOCS_DEST, SWITCHER_JSON_NAME), "w") as outfile:
        json.dump(contents, outfile)
    redirects_contents = f"""/{PROJECT_NAME}/ /{PROJECT_NAME}/{default_version}/ 302
/{PROJECT_NAME}/index.html /{PROJECT_NAME}/{default_version}/index.html 302"""
    print(f"WRITING {REDIRECTS_NAME}:\n")
    print(redirects_contents)
    with open(os.path.join(DOCS_DEST, REDIRECTS_NAME), "w") as outfile:
        outfile.write(redirects_contents)
