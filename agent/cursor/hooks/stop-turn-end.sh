#!/usr/bin/env bash
# stop hook: notify MOCA and the broker when an agent turn completes.
exec bash ~/.local/bin/emit-turn-end.sh cursor success
