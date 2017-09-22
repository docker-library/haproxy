#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$SYSLOGD" -eq 1 ]; then
	dumb-init -r 1:0 -r 12:0 -- syslogd -nLO- &
fi

exec "$@"
