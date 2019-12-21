#!/bin/bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

defaultDebianSuite='buster-slim'
declare -A debianSuite=(
	[1.6]='stretch-slim'
	[1.5]='stretch-slim'
)
defaultAlpineVersion='3.11'
declare -A alpineVersion=(
	[1.5]='3.8'
	[1.6]='3.8'
)

travisEnv=
for version in "${versions[@]}"; do
	rcGrepV='-v'
	rcVersion="${version%-rc}"
	if [ "$rcVersion" != "$version" ]; then
		rcGrepV=
	fi

	fullVersion="$(
		{
			curl -fsSL --compressed 'https://www.haproxy.org/download/'"$rcVersion"'/src/'
			if [ "$rcVersion" != "$version" ]; then
				curl -fsSL --compressed 'https://www.haproxy.org/download/'"$rcVersion"'/src/devel/'
			fi
		} \
			| grep -o '<a href="haproxy-'"$rcVersion"'[^"/]*\.tar\.gz"' \
			| sed -r 's!^<a href="haproxy-([^"/]+)\.tar\.gz"$!\1!' \
			| grep $rcGrepV -E 'rc|dev' \
			| sort -V \
			| tail -1
	)"
	url="https://www.haproxy.org/download/$rcVersion/src"
	if [[ "$fullVersion" == *dev* ]]; then
		url+='/devel'
	fi
	url+="/haproxy-$fullVersion.tar.gz"
	sha256="$(curl -fsSL --compressed "$url.sha256" | cut -d' ' -f1)"

	echo "$version: $fullVersion ($sha256, $url)"

	versionSuite="${debianSuite[$version]:-$defaultDebianSuite}"
	alpine="${alpineVersion[$version]:-$defaultAlpineVersion}"
	sedExpr='
			s/%%ALPINE_VERSION%%/'"$alpine"'/;
			s/%%DEBIAN_VERSION%%/'"$versionSuite"'/;
			s/%%HAPROXY_VERSION%%/'"$fullVersion"'/;
			s!%%HAPROXY_URL%%!'"$url"'!;
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
	if [[ "$version" = 1.* ]]; then
		sedExpr+='
			s/linux-glibc/linux2628/;
			/prometheus/d;
		'
	fi
	sed -r "$sedExpr" 'Dockerfile-debian.template' > "$version/Dockerfile"

	for variant in alpine; do
		[ -d "$version/$variant" ] || continue
		if [ "$version" = '1.7' ]; then
			sedExpr+='
				/makeOpts=/a \\t\tCFLAGS+="-Wno-address-of-packed-member" \\
			'
		fi
		sed -r "$sedExpr" 'Dockerfile-alpine.template' > "$version/$variant/Dockerfile"
		travisEnv='\n  - VERSION='"$version VARIANT=$variant$travisEnv"
	done

	travisEnv='\n  - VERSION='"$version ARCH=i386$travisEnv"
	travisEnv='\n  - VERSION='"$version VARIANT=$travisEnv"
done

travis="$(awk -v 'RS=\n\n' '$1 == "env:" { $0 = "env:'"$travisEnv"'" } { printf "%s%s", $0, RS }' .travis.yml)"
echo "$travis" > .travis.yml
