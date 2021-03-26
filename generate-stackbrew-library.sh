#!/usr/bin/env bash
set -Eeuo pipefail

# https://www.haproxy.org/#down ("LTS" vs "latest")
declare -A aliases=(
	[2.2]='lts'
	[2.3]='latest'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

if [ "$#" -eq 0 ]; then
	versions="$(jq -r 'keys | map(@sh) | join(" ")' versions.json)"
	eval "set -- $versions"
fi

# sort version numbers with highest first
IFS=$'\n'; set -- $(sort -rV <<<"$*"); unset IFS

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

getArches() {
	local repo="$1"; shift
	local officialImagesUrl='https://github.com/docker-library/official-images/raw/master/library/'

	eval "declare -g -A parentRepoToArches=( $(
		find -name 'Dockerfile' -exec awk '
				toupper($1) == "FROM" && $2 !~ /^('"$repo"'|scratch|.*\/.*)(:|$)/ {
					print "'"$officialImagesUrl"'" $2
				}
			' '{}' + \
			| sort -u \
			| xargs bashbrew cat --format '[{{ .RepoName }}:{{ .TagName }}]="{{ join " " .TagEntry.Architectures }}"'
	) )"
}
getArches 'haproxy'

cat <<-EOH
# this file is generated via https://github.com/docker-library/haproxy/blob/$(fileCommit "$self")/$self

Maintainers: Tianon Gravi <admwiggin@gmail.com> (@tianon),
             Joseph Ferguson <yosifkit@gmail.com> (@yosifkit)
GitRepo: https://github.com/docker-library/haproxy.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version; do
	export version

	fullVersion="$(jq -r '.[env.version].version' versions.json)"

	# dcorbett(-haproxy): maybe just a simple "-dev" without the 0 which always follows the latest dev branch
	tagVersion="$version"
	if [[ "$version" == *-rc ]] && [[ "$fullVersion" == *-dev* ]]; then
		tagVersion="${version%-rc}-dev"
	fi

	versionAliases=(
		$fullVersion
		$tagVersion
		${aliases[$version]:-}
	)

	for variant in '' alpine; do
		export variant
		dir="$version${variant:+/$variant}"

		commit="$(dirCommit "$dir")"

		if [ -n "$variant" ]; then
			variantAliases=( "${versionAliases[@]/%/-$variant}" )
			variantAliases=( "${variantAliases[@]//latest-/}" )
		else
			variantAliases=( "${versionAliases[@]}" )
		fi

		parent="$(awk 'toupper($1) == "FROM" { print $2 }' "$dir/Dockerfile")"
		arches="${parentRepoToArches[$parent]}"

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: $(join ', ' $arches)
			GitCommit: $commit
			Directory: $dir
		EOE
	done
done
