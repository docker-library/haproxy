#!/bin/bash
set -eo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

defaultDebianSuite='stretch-slim'
declare -A debianSuite=(
	[1.5]='jessie'
)
defaultAlpineVersion='3.7'
declare -A alpineVersion=(
	[1.5]='3.5'
)

travisEnv=
for version in "${versions[@]}"; do
	rcGrepV='-v'
	rcVersion="${version%-rc}"
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi

	fullVersion="$(
		curl -sSL --compressed 'https://www.haproxy.org/download/'"$rcVersion"'/src/' \
			| grep '<a href="haproxy-'"$version"'.*\.tar\.gz"' \
			| grep $rcGrepV -E 'rc' \
			| sed -r 's!.*<a href="haproxy-([^"/]+)\.tar\.gz".*!\1!' \
			| sort -V \
			| tail -1
	)"
	md5="$(curl -sSL --compressed 'https://www.haproxy.org/download/'"$rcVersion"'/src/haproxy-'"$fullVersion"'.tar.gz.md5' | cut -d' ' -f1)"

	versionSuite="${debianSuite[$version]:-$defaultDebianSuite}"
	alpine="${alpineVersion[$version]:-$defaultAlpineVersion}"
	sedExpr='
			s/%%ALPINE_VERSION%%/'"$alpine"'/;
			s/%%DEBIAN_VERSION%%/'"$versionSuite"'/;
			s/%%HAPROXY_MAJOR%%/'"$rcVersion"'/;
			s/%%HAPROXY_VERSION%%/'"$fullVersion"'/;
			s/%%HAPROXY_MD5%%/'"$md5"'/;
		'
	( set -x; sed -r "$sedExpr" 'Dockerfile-debian.template' > "$version/Dockerfile" )
	
	for variant in alpine; do
		[ -d "$version/$variant" ] || continue
		( set -x; sed -r "$sedExpr" 'Dockerfile-alpine.template' > "$version/$variant/Dockerfile" )
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done

	if [ "$version" = '1.5' ]; then
		for dockerfile in "$version/Dockerfile" "$version/$variant/Dockerfile"; do
			sed -ri -e '/lua/d' -e 's/libssl1.1/libssl1.0.0/' "$dockerfile"
		done
	fi

	travisEnv='\n  - VERSION='"$version ARCH=i386$travisEnv"
	travisEnv='\n  - VERSION='"$version VARIANT=$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
