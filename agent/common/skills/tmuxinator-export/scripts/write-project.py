#!/usr/bin/env python3
"""Create one tmuxinator project without following links or overwriting."""

import os
import pathlib
import re
import sys
from typing import NoReturn


def fail(message: str) -> NoReturn:
    print(f"tmuxinator-export: {message}", file=sys.stderr)
    raise SystemExit(1)


if len(sys.argv) != 2:
    fail("usage: write-project.py DESTINATION")

destination = pathlib.Path(sys.argv[1]).expanduser()
if not destination.is_absolute() or not re.fullmatch(
    r"[A-Za-z0-9_-]+\.(?:yml|yaml)", destination.name
):
    fail("destination must be an absolute .yml or .yaml path")

payload = sys.stdin.buffer.read()
if not payload:
    fail("refusing to create an empty project")

parent = destination.parent
if ".." in parent.parts:
    fail("config directory must not contain parent traversal")

directory_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
if hasattr(os, "O_NOFOLLOW"):
    directory_flags |= os.O_NOFOLLOW

directory_fd = None
try:
    directory_fd = os.open("/", directory_flags)
    for component in parent.parts[1:]:
        try:
            os.mkdir(component, mode=0o700, dir_fd=directory_fd)
        except FileExistsError:
            pass
        next_fd = os.open(component, directory_flags, dir_fd=directory_fd)
        os.close(directory_fd)
        directory_fd = next_fd
except OSError:
    if directory_fd is not None:
        os.close(directory_fd)
    fail("config directory must be a real directory, not a symbolic link")

file_fd = None
try:
    file_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        file_flags |= os.O_NOFOLLOW
    file_fd = os.open(destination.name, file_flags, 0o600, dir_fd=directory_fd)
    with os.fdopen(file_fd, "wb", closefd=True) as output:
        file_fd = None
        output.write(payload)
        output.flush()
        os.fsync(output.fileno())
except FileExistsError:
    fail("destination already exists; refusing to overwrite")
except OSError:
    if file_fd is not None:
        os.close(file_fd)
    try:
        os.unlink(destination.name, dir_fd=directory_fd)
    except OSError:
        pass
    fail("could not create project safely")
finally:
    os.close(directory_fd)
