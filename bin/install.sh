#!/bin/bash
script_dir="$(cd "$(dirname "${BASH_SOURCE:-${(%):-%N}}")"; pwd)"
cd "$script_dir/../"

for f in .??*
do
  [ "$f" == ".git" ] && continue
  [ "$f" == ".DS_Store" ] && continue

  ln -snfv "$f" "$HOME"/"$f"
  echo "copied: $f"
done

