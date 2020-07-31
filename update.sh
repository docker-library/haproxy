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
	#[1.6]='stretch-slim'
)
defaultAlpineVersion='3.12'
declare -A alpineVersion=(
	#[1.6]='3.8'
)

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

	if [[ "$version" = 1.* ]]; then
		sedExpr+='
			s/linux-glibc/linux2628/;
			s/linux-musl/linux2628/;
			/prometheus/d;
		'
	fi
	if [ "$version" = '2.0' ]; then
		sedExpr+='
			s/linux-musl/linux-glibc/;
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
	done
done
