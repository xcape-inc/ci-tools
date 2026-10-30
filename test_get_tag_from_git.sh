#!/usr/bin/env bash
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/get_tag_from_git.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
git init -q -b main
git config user.name Test
git config user.email test@example.invalid
git commit -q --allow-empty -m initial
git tag MPT-20261030T054248Z-824bd4001c2d
source "$script" >/dev/null
test "$CUR_VERSION" = v0.0.1a1

git tag v1.2.3
git commit -q --allow-empty -m next
git tag MPT-later
source "$script" >/dev/null
test "$CUR_VERSION" = v1.2.4rc1

echo 'version tag selection passed'
