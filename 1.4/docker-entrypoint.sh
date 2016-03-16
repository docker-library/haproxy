#!/bin/bash
set -eo pipefail

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- haproxy "$@"
fi

exec "$@"
