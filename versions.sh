#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
	json='{}'
else
	json="$(< versions.json)"
fi
versions=( "${versions[@]%/}" )

defaultDebianSuite='bullseye-slim'
declare -A debianSuite=(
	[1.8]='buster-slim'
	[2.0]='buster-slim'
)
defaultAlpineVersion='3.15'
declare -A alpineVersion=(
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

	export version fullVersion sha256 url versionSuite alpine
	json="$(jq <<<"$json" -c '
		.[env.version] = {
			version: env.fullVersion,
			sha256: env.sha256,
			url: env.url,
			debian: env.versionSuite,
			alpine: env.alpine,
		}
	')"
done

jq <<<"$json" -S . > versions.json
