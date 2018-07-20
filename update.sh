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
	#[1.6]='jessie-backports'
	#[1.5]='jessie'
)
defaultAlpineVersion='3.8'
declare -A alpineVersion=(
	#[1.5]='3.5'
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
	sha256="$(curl -sSL --compressed 'https://www.haproxy.org/download/'"$rcVersion"'/src/haproxy-'"$fullVersion"'.tar.gz.sha256' | cut -d' ' -f1)"

	versionSuite="${debianSuite[$version]:-$defaultDebianSuite}"
	alpine="${alpineVersion[$version]:-$defaultAlpineVersion}"
	sedExpr='
			s/%%ALPINE_VERSION%%/'"$alpine"'/;
			s/%%DEBIAN_VERSION%%/'"$versionSuite"'/;
			s/%%HAPROXY_MAJOR%%/'"$rcVersion"'/;
			s/%%HAPROXY_VERSION%%/'"$fullVersion"'/;
			s/%%HAPROXY_SHA256%%/'"$sha256"'/;
		'

	if [ "$version" = '1.5' ]; then
		sedExpr+='
			/lua/d;
		'
	fi
	if [ "$version" = 1.5 ] || [ "$version" = 1.6 ]; then
		# libssl1.1 is not supported until 1.7+
		# https://git.haproxy.org/?p=haproxy-1.7.git;a=commitdiff;h=1866d6d8f1163fe28a1e8256080909a5aa166880
		sedExpr+='
			s/libssl-dev/libssl1.0-dev/;
		'
	fi
	( set -x; sed -r "$sedExpr" 'Dockerfile-debian.template' > "$version/Dockerfile" )
	
	for variant in alpine; do
		[ -d "$version/$variant" ] || continue
		( set -x; sed -r "$sedExpr" 'Dockerfile-alpine.template' > "$version/$variant/Dockerfile" )
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done

	travisEnv='\n  - VERSION='"$version ARCH=i386$travisEnv"
	travisEnv='\n  - VERSION='"$version VARIANT=$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
