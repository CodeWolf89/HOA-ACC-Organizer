#!/usr/bin/env python3
# Copyright © 2026 Christopher Mcmahon-Sutton.
# Licensed under the PolyForm Perimeter License 1.0.1.
# Author: Christopher Mcmahon-Sutton.
# Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
# See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

"""Audit DocC comments on module- and type-member Swift declarations.

This deliberately ignores function-local variables because they are not emitted as
DocC symbols. The goal is to keep every declaration that can describe the app's
API/implementation surface documented for future maintainers.
"""

from __future__ import annotations

from pathlib import Path
import re
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = PROJECT_ROOT / "HOA ACC Organizer"

TYPE_KINDS = {"struct", "class", "enum", "actor", "protocol", "extension", "typealias"}
KEYWORDS = ["struct", "class", "enum", "actor", "protocol", "extension", "typealias", "func", "var", "let", "init", "subscript", "deinit"]
MODIFIERS = {
    "public", "private", "fileprivate", "internal", "open", "final", "static",
    "nonisolated", "override", "mutating", "nonmutating", "required",
    "convenience", "lazy", "weak", "unowned", "indirect", "prefix", "postfix",
    "infix", "distributed",
}


def consume_attribute(source: str) -> str | None:
    if not source.startswith("@"):
        return None

    index = 1
    while index < len(source) and (source[index].isalnum() or source[index] in "._"):
        index += 1

    if index < len(source) and source[index] == "(":
        depth = 0
        in_string = False
        escaped = False
        while index < len(source):
            character = source[index]
            if in_string:
                if escaped:
                    escaped = False
                elif character == "\\":
                    escaped = True
                elif character == '"':
                    in_string = False
            else:
                if character == '"':
                    in_string = True
                elif character == "(":
                    depth += 1
                elif character == ")":
                    depth -= 1
                    if depth == 0:
                        index += 1
                        break
            index += 1

    while index < len(source) and source[index].isspace():
        index += 1
    return source[index:]


def strip_prefix(source: str) -> str:
    text = source.strip()

    while text.startswith("@"):
        remainder = consume_attribute(text)
        if remainder is None or remainder == text:
            break
        text = remainder.lstrip()

    while True:
        setter = re.match(r"^(private|public|fileprivate|internal)\s*\(set\)\s+", text)
        if setter:
            text = text[setter.end():]
            continue

        if re.match(r"^class\s+(func|var|subscript)\b", text):
            text = re.sub(r"^class\s+", "", text, count=1)
            continue

        modifier = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s+", text)
        if modifier and modifier.group(1) in MODIFIERS:
            text = text[modifier.end():]
            continue
        break

    return text


def declaration(line: str):
    if not line.strip() or line.lstrip().startswith("//"):
        return None

    stripped = line.lstrip()
    if stripped.startswith(("#", "case ", "if ", "guard ", "for ", "while ", "switch ", "return ", "throw ", "catch ", "else")):
        return None

    normalized = strip_prefix(stripped)
    kind = next((keyword for keyword in KEYWORDS if re.match(rf"^{keyword}\b", normalized)), None)
    if kind is None:
        return None

    remainder = normalized[len(kind):].lstrip()
    if kind in {"init", "subscript", "deinit"}:
        name = kind
    else:
        name_match = re.match(r"([A-Za-z_][A-Za-z0-9_.<>]*)", remainder)
        name = name_match.group(1) if name_match else kind

    return {
        "kind": kind,
        "name": name,
        "indent": len(line) - len(stripped),
    }


def collect_declarations(lines: list[str]):
    declarations = []
    for index, line in enumerate(lines):
        parsed = declaration(line)
        if parsed:
            parsed["index"] = index
            declarations.append(parsed)
    return declarations


def is_symbol(declarations, position: int) -> bool:
    current = declarations[position]
    if current["indent"] == 0:
        return True

    for previous in range(position - 1, -1, -1):
        parent = declarations[previous]
        if parent["indent"] < current["indent"]:
            return parent["kind"] in TYPE_KINDS
    return False


def has_doc_comment(lines: list[str], index: int) -> bool:
    previous = index - 1
    while previous >= 0 and lines[previous].strip().startswith("@") and declaration(lines[previous]) is None:
        previous -= 1
    while previous >= 0 and not lines[previous].strip():
        previous -= 1

    if previous < 0:
        return False

    text = lines[previous].lstrip()
    return text.startswith("///") or text.startswith("/**") or text.startswith("*") or text.startswith("*/")


def main() -> int:
    undocumented = []
    documented = 0
    total = 0

    for swift_file in sorted(SOURCE_ROOT.glob("*.swift")):
        lines = swift_file.read_text(encoding="utf-8", errors="ignore").splitlines()
        declarations = collect_declarations(lines)

        for position, item in enumerate(declarations):
            if not is_symbol(declarations, position):
                continue

            total += 1
            if has_doc_comment(lines, item["index"]):
                documented += 1
            else:
                undocumented.append(
                    (swift_file.name, item["index"] + 1, item["kind"], item["name"])
                )

    coverage = (documented / total * 100) if total else 100.0
    print(f"DocC symbol coverage: {documented}/{total} ({coverage:.1f}%)")

    if undocumented:
        print("\nUndocumented declarations:")
        for file_name, line, kind, name in undocumented:
            print(f"- {file_name}:{line}  {kind} {name}")
        return 1

    print("All module-level and type-member declarations in the app target have documentation comments.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
