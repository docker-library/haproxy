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

defaultDebianSuite='bookworm-slim'
declare -A debianSuite=(
)
defaultAlpineVersion='3.21'
declare -A alpineVersion=(
)

for version in "${versions[@]}"; do
	export version
	export url="https://www.haproxy.org/download/$version/src"
	export debian="${debianSuite[$version]:-$defaultDebianSuite}"
	export alpine="${alpineVersion[$version]:-$defaultAlpineVersion}"

	doc="$(
		curl -fsSL "$url/releases.json" | jq -c '
			{ version: .latest_release } + .releases[.latest_release]
			| {
				version: .version,
				url: (env.url + "/" + .file),
				sha256: .sha256,
				debian: env.debian,
				alpine: env.alpine,
			}
		'
	)"

	jq <<<"$doc" -r 'env.version + ": " + .version'
	json="$(jq <<<"$json" -c --argjson doc "$doc" '.[env.version] = $doc')"
done

jq <<<"$json" -S . > versions.json
