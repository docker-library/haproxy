#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ ! -S "/dev/log" ]; then
	syslogd -O /dev/stdout -S
fi

exec "$@"
