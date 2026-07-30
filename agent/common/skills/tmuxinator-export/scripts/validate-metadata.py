#!/usr/bin/env python3
"""Collect tmux fields without delimiter ambiguity and emit validated TSV."""

from __future__ import annotations

import os
import re
import subprocess
import unicodedata
from collections import defaultdict
from typing import NoReturn

SAFE_COMMAND = re.compile(r"[A-Za-z0-9._+-]+")
SENSITIVE_TEXT = re.compile(
    r"[A-Za-z][A-Za-z0-9+.-]*://|"
    r"(?:^|[/\s])[A-Za-z_][A-Za-z0-9_-]*\s*=",
    re.IGNORECASE,
)
FIELDS = (
    "window_index",
    "window_name",
    "window_layout",
    "window_active",
    "pane_index",
    "pane_id",
    "pane_active",
    "pane_current_path",
    "pane_current_command",
)


def reject() -> NoReturn:
    raise SystemExit(1)


def tmux_output(*arguments: str, multiline: bool = False) -> str:
    try:
        result = subprocess.run(
            ("tmux", *arguments),
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        text = result.stdout.decode("utf-8")
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        reject()
    if not text.endswith("\n"):
        reject()
    value = text[:-1]
    allowed_controls = "\n" if multiline else ""
    if not value or any(
        unicodedata.category(character).startswith("C")
        and character not in allowed_controls
        for character in value
    ):
        reject()
    return value


def parse_uint(value: str, position: int) -> tuple[int, int]:
    end = position
    while end < len(value) and value[end].isdigit():
        end += 1
    if end == position:
        reject()
    return int(value[position:end]), end


def parse_cell(value: str, position: int) -> tuple[set[int], int]:
    _, position = parse_uint(value, position)
    if position >= len(value) or value[position] != "x":
        reject()
    _, position = parse_uint(value, position + 1)
    if position >= len(value) or value[position] != ",":
        reject()
    _, position = parse_uint(value, position + 1)
    if position >= len(value) or value[position] != ",":
        reject()
    _, position = parse_uint(value, position + 1)
    if position >= len(value):
        reject()

    marker = value[position]
    if marker == ",":
        pane_id, position = parse_uint(value, position + 1)
        return {pane_id}, position
    if marker not in "{[":
        reject()

    closing = "}" if marker == "{" else "]"
    pane_ids: set[int] = set()
    child_count = 0
    position += 1
    while True:
        child_ids, position = parse_cell(value, position)
        if pane_ids.intersection(child_ids):
            reject()
        pane_ids.update(child_ids)
        child_count += 1
        if position >= len(value):
            reject()
        if value[position] == closing:
            if child_count < 2:
                reject()
            return pane_ids, position + 1
        if value[position] != ",":
            reject()
        position += 1


def validate_layout(value: str) -> set[int]:
    if not re.fullmatch(r"[0-9A-Fa-f]{4},[][0-9x,{}]+", value):
        reject()
    pane_ids, position = parse_cell(value, 5)
    if position != len(value):
        reject()
    return pane_ids


def collect_rows(session: str) -> list[list[str]]:
    pane_output = tmux_output(
        "list-panes", "-s", "-t", f"={session}", "-F", "#{pane_id}", multiline=True
    )
    pane_ids = pane_output.split("\n")
    if len(set(pane_ids)) != len(pane_ids) or not all(
        re.fullmatch(r"%[0-9]+", pane_id) for pane_id in pane_ids
    ):
        reject()

    rows = []
    for pane_id in pane_ids:
        row = [
            tmux_output("display-message", "-p", "-t", pane_id, f"#{{{field}}}")
            for field in FIELDS
        ]
        if row[5] != pane_id:
            reject()
        rows.append(row)
    return rows


def validate_rows(rows: list[list[str]]) -> list[list[str]]:
    ordered_rows: list[tuple[int, int, list[str]]] = []
    windows: dict[int, tuple[str, str, int]] = {}
    pane_ids_by_window: dict[int, set[int]] = defaultdict(set)
    active_panes_by_window: dict[int, int] = defaultdict(int)
    seen_pane_ids: set[int] = set()
    seen_pane_indices: set[tuple[int, int]] = set()

    for fields in rows:
        (
            window_index_raw,
            window_name,
            window_layout,
            window_active_raw,
            pane_index_raw,
            pane_id_raw,
            pane_active_raw,
            pane_current_path,
            pane_current_command,
        ) = fields

        numeric_fields = (
            window_index_raw,
            window_active_raw,
            pane_index_raw,
            pane_active_raw,
        )
        if not all(value.isascii() and value.isdigit() for value in numeric_fields):
            reject()
        window_index = int(window_index_raw)
        window_active = int(window_active_raw)
        pane_index = int(pane_index_raw)
        pane_active = int(pane_active_raw)
        if window_active not in (0, 1) or pane_active not in (0, 1):
            reject()
        pane_id = int(pane_id_raw[1:])
        if not SAFE_COMMAND.fullmatch(pane_current_command):
            reject()
        if not pane_current_path.startswith("/") or ".." in pane_current_path.split(
            "/"
        ):
            reject()
        if any(
            SENSITIVE_TEXT.search(value)
            for value in (window_name, pane_current_path, pane_current_command)
        ):
            reject()

        window_facts = (window_name, window_layout, window_active)
        if window_index in windows and windows[window_index] != window_facts:
            reject()
        windows[window_index] = window_facts
        if pane_id in seen_pane_ids or (window_index, pane_index) in seen_pane_indices:
            reject()
        seen_pane_ids.add(pane_id)
        seen_pane_indices.add((window_index, pane_index))
        pane_ids_by_window[window_index].add(pane_id)
        active_panes_by_window[window_index] += pane_active
        ordered_rows.append((window_index, pane_index, fields))

    if sum(facts[2] for facts in windows.values()) != 1:
        reject()
    for window_index, (_, layout, _) in windows.items():
        if active_panes_by_window[window_index] != 1:
            reject()
        if validate_layout(layout) != pane_ids_by_window[window_index]:
            reject()

    ordered_rows.sort(key=lambda row: (row[0], row[1]))
    return [row[2] for row in ordered_rows]


def main() -> None:
    pane = os.environ.get("TMUX_PANE", "")
    if not re.fullmatch(r"%[0-9]+", pane):
        reject()
    session = tmux_output("display-message", "-p", "-t", pane, "#{session_name}")
    if session.startswith("_") or SENSITIVE_TEXT.search(session):
        reject()

    rows = validate_rows(collect_rows(session))
    print(f"session\t{session}")
    print("\t".join(FIELDS))
    for row in rows:
        print("\t".join(row))


if __name__ == "__main__":
    main()
