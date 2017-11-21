#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
	set -- haproxy "$@"
fi

if [ "$1" = 'haproxy' ]; then
	shift # "haproxy"
	# if the user wants "haproxy", let's add a couple useful flags
	#   haproxy-systemd-wrapper -- "master-worker mode" (similar to the new "-W" flag; allows for reload via "SIGUSR2")
	#   -db -- disables background mode
	set -- "$(which haproxy-systemd-wrapper)" -p /run/haproxy.pid -db "$@"
fi

exec "$@"
