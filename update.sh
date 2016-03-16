#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )


travisEnv=
for version in "${versions[@]}"; do
	fullVersion="$(curl -sSL --compressed 'http://www.haproxy.org/download/'"$version"'/src/' | grep '<a href="haproxy-'"$version"'.*\.tar\.gz"' | sed -r 's!.*<a href="haproxy-([^"/]+)\.tar\.gz".*!\1!' | sort -V | tail -1)"
	md5="$(curl -sSL --compressed 'http://www.haproxy.org/download/'"$version"'/src/haproxy-'"$fullVersion"'.tar.gz.md5' | cut -d' ' -f1)"
	sedExpr='
			s/^(ENV HAPROXY_MAJOR) .*/\1 '"$version"'/;
			s/^(ENV HAPROXY_VERSION) .*/\1 '"$fullVersion"'/;
			s/^(ENV HAPROXY_MD5) .*/\1 '"$md5"'/;
		'
	( set -x; sed -ri "$sedExpr" "$version/Dockerfile" )
	
	for variant in alpine; do
		[ -d "$version/$variant" ] || continue
		( set -x; sed -ri "$sedExpr" "$version/$variant/Dockerfile" )
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done
	travisEnv='\n  - VERSION='"$version VARIANT=$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
