#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do
	fullVersion="$(curl -sSL --compressed 'http://www.haproxy.org/download/'"$version"'/src/' | grep '<a href="haproxy-'"$version"'.*\.tar\.gz"' | sed -r 's!.*<a href="haproxy-([^"/]+)\.tar\.gz".*!\1!' | sort -V | tail -1)"
	md5="$(curl -sSL --compressed 'http://www.haproxy.org/download/'"$version"'/src/haproxy-'"$fullVersion"'.tar.gz.md5' | cut -d' ' -f1)"
	(
		set -x
		sed -ri '
			s/^(ENV HAPROXY_MAJOR) .*/\1 '"$version"'/;
			s/^(ENV HAPROXY_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV HAPROXY_MD5) .*/\1 '"$md5"'/;
		' "$version/Dockerfile"
	)
done
