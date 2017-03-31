#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$SYSLOGD" -eq 1 ]; then
	syslogd -nLO- &
fi

exec "$@"
