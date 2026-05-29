#!/usr/bin/env bash

set -euo pipefail
[ $# -le 1 ] || exit 2
cd "`dirname "$0"`/.."

# Guard against accidental plain-text Diet branches in `views/log.dt`.
# Those render as literal <if>/<else> tags and duplicate whole sections.
if grep -nE '^[[:space:]]+(if[[:space:]]|else([[:space:]]+if)?$)' views/log.dt >/tmp/logdt_bad_branches.txt; then
	echo "ERROR: non-executable Diet branch syntax found in views/log.dt:" >&2
	cat /tmp/logdt_bad_branches.txt >&2
	echo "Use '- if (...)', '- else if (...)' and '- else' instead." >&2
	exit 1
fi
rm -f /tmp/logdt_bad_branches.txt

./waf configure build
DFLAGS=-mcpu=native dub build -brelease
[ "${1-}" = --no-restart ] || exec supervisorctl -c supervisord.conf restart gvrepsrv
