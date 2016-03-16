#!/bin/bash
set -eo pipefail

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	# if the user wants "haproxy", let's use "haproxy-systemd-wrapper" instead so we can have proper reloadability implemented by upstream
	shift # "haproxy"
	set -- "$(which haproxy-systemd-wrapper)" -p /run/haproxy.pid "$@"
fi

if [ ! -S "/dev/log" ]; then
	syslogd -O /dev/stdout -S
fi

exec "$@"
