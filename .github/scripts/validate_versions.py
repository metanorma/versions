#!/usr/bin/env python3
"""Validate data/gemfile/versions.yaml against schemas/gemfile-versions.schema.json.

Exits non-zero on any schema violation. Uses jsonschema (pip install jsonschema
PyYAML referencing) — installed by the validate-versions workflow.

Usage:
    python3 .github/scripts/validate_versions.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from referencing import Registry, Resource

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_DIR = REPO_ROOT / "schemas"
DATA_FILE = REPO_ROOT / "data" / "gemfile" / "versions.yaml"
ROOT_SCHEMA = SCHEMA_DIR / "gemfile-versions.schema.json"
ENTRY_SCHEMA = SCHEMA_DIR / "gemfile-version.schema.json"


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def load_schema(path: Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def build_registry() -> Registry:
    """Register every schema under schemas/ by its $id, so $refs resolve."""
    registry = Registry()
    for path in SCHEMA_DIR.glob("*.schema.json"):
        schema = load_schema(path)
        registry = registry.with_resource(schema["$id"], Resource.from_contents(schema))
    return registry


def main() -> int:
    if not DATA_FILE.exists():
        print(f"missing data file: {DATA_FILE}", file=sys.stderr)
        return 2
    if not ROOT_SCHEMA.exists():
        print(f"missing schema: {ROOT_SCHEMA}", file=sys.stderr)
        return 2

    root_schema = load_schema(ROOT_SCHEMA)
    validator = Draft202012Validator(
        root_schema,
        registry=build_registry(),
        format_checker=FormatChecker(),
    )

    data = load_yaml(DATA_FILE)
    errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
    if not errors:
        n = len(data.get("versions") or [])
        print(f"OK — {n} version entries valid against {ROOT_SCHEMA.name}")
        return 0

    print(f"FAIL — {len(errors)} schema violation(s) in {DATA_FILE}:",
          file=sys.stderr)
    for err in errors:
        loc = ".".join(str(p) for p in err.absolute_path) or "<root>"
        print(f"  {loc}: {err.message}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
