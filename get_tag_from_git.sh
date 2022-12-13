#!/bin/bash
set -e
trap 'catch $? $LINENO' ERR
catch() {
  echo "Error $1 occurred on $2"
}
set -euo pipefail

# If there this is a fresh git init, there has never been a commit, so 0000000 is a palce holder
RAW_COMMIT_SHORT_SHA=$(git rev-parse --short HEAD 2> /dev/null || true)
COMMIT_SHORT_SHA=${RAW_COMMIT_SHORT_SHA:-0000000}
# if the commit is unset, there is no HEAD ref, so skip this.  If we are detached, this will be the reserved word HEAD
if [[ '' == "${RAW_COMMIT_SHORT_SHA:-}" ]]; then
  GIT_BRANCH=$(git branch --show-current)
else
  GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
fi
GIT_DESCRIBE=$((git describe --tags --dirty --long 2> /dev/null) || true)
LAST_TAG_COMMIT=$(git rev-list --tags --no-walk --max-count=1)
IS_DIRTY=$(git diff --quiet || echo '_DIRTY')
RAW_LAST_TAG=$((git describe --tags "${LAST_TAG_COMMIT}" 2> /dev/null) || true)
LAST_TAG=${RAW_LAST_TAG:-v0.0.0}

# Check the tag format; throw an error if its wrong
if [[ "${LAST_TAG:-}" =~ ^(v)?([0-9]+)(.[0-9]+)*$ ]]; then
  # Pattern good; nothing to do
  :;
else
  echo "'${LAST_TAG:-}' does not match the required tag pattern (eg. v1.0.0)" >&2 && false
fi
LAST_PART_LAST_TAG=${LAST_TAG##*.}
FIRST_PART_LAST_TAG=${LAST_TAG%${LAST_PART_LAST_TAG}}

# There were no . , so something like v14
if [[ '' == "${FIRST_PART_LAST_TAG:-}" ]]; then
  LAST_PART_LAST_TAG=${LAST_TAG#*v}
  FIRST_PART_LAST_TAG=${LAST_TAG%${LAST_PART_LAST_TAG}}
fi

# Get the number of commits ever if there has never been a tag
if [[ "" == "${LAST_TAG_COMMIT:-}" ]]; then
  # if there are no commits, this is 0
  if [[ '' == "${RAW_COMMIT_SHORT_SHA:-}" ]]; then
    COMMIT_COUNT=0
    # Note: all commits in history?
    # git rev-list --count --all
  # otherwise, since there are no tags, it is all commits to head (count since first + 1)
  else
    FIRST_COMMIT_HASH=$(git rev-list --max-parents=0 HEAD)
    COMMIT_COUNT=$(git rev-list "${FIRST_COMMIT_HASH}..HEAD" --count)
    COMMIT_COUNT=$((${COMMIT_COUNT}+1))
  fi
# Get the number of commits since the last tag if there has been a tag
else
  COMMIT_COUNT=$(git rev-list "${LAST_TAG_COMMIT}..HEAD" --count)
fi

PRE_RELEASE_SUFFIX=""
# if the repo is dirty, there's never been a tag, or the commit-since-last-tag count is non-zero and branch is something other than master, main, or develop, is alpha
if [[ '_DIRTY' == ${IS_DIRTY:-} || '' == ${RAW_LAST_TAG} || ("0" != "${COMMIT_COUNT}" && "main" != "${GIT_BRANCH}" && "master" != "${GIT_BRANCH}" && "develop" != "${GIT_BRANCH}") ]]; then
  PRE_RELEASE_SUFFIX='a'
# if commit count is 0, we are on a release; do not se the value
elif [[ "0" == "${COMMIT_COUNT}" ]]; then
  :;
# If this is the develop branch, this is beta
elif [[ "develop" == "${GIT_BRANCH}" ]]; then
  PRE_RELEASE_SUFFIX='b'
# logically the COMMIT_COUNT is non-zero and the branch name is either master or main, making this an rc build
else
  PRE_RELEASE_SUFFIX='rc'
fi

# If there has never been a commit and the repo is not dirty (init only), this is a special case where the version should be 0.0.0
# resulting in an effective version of v0.0.0a0, indicating this is alpha with no commits whatsoever
if [[ '' == "${IS_DIRTY:-}" && '' == "${RAW_COMMIT_SHORT_SHA}" ]]; then
  PRE_RELEASE_SUFFIX='a'
#  need to set this if PRE_RELEASE_SUFFIX has a value
elif [[ "" != "${PRE_RELEASE_SUFFIX:-}" ]]; then
  LAST_PART_NEXT_TAG=$((${LAST_PART_LAST_TAG}+1))
  NEXT_TAG=${FIRST_PART_LAST_TAG:-}${LAST_PART_NEXT_TAG}
fi

# NEXT_TAG is set if this is a non-release commit; else the version is the same as the last tag
CUR_VERSION=${NEXT_TAG:-${LAST_TAG}}
# if this is a pre-release build, append the pre-release suffix and the commit number
if [[ "" != "${PRE_RELEASE_SUFFIX:-}" ]]; then
  CUR_VERSION=${CUR_VERSION}${PRE_RELEASE_SUFFIX}${COMMIT_COUNT}
fi

# TODO: drop the leading v

# TODO: santize GIT_BRANCH to fit python scheme; this can be translated for deb
SANITIZED_GIT_BRANCH=${GIT_BRANCH}

# The long form of version info for releas is the same as short
LONG_FORM_CUR_VERSION=${CUR_VERSION}
# If this is not a release, show more or less the second part of git describe combined with the short CUR_VERSION
if [[ "" != "${PRE_RELEASE_SUFFIX:-}" ]]; then
  LONG_FORM_CUR_VERSION=${LONG_FORM_CUR_VERSION}+${COMMIT_COUNT}-g${COMMIT_SHORT_SHA}${IS_DIRTY:-}-${SANITIZED_GIT_BRANCH}
fi

#echo "${GIT_DESCRIBE:-N/A}"
#echo "${LAST_TAG} - ${COMMIT_COUNT} - g${COMMIT_SHORT_SHA} - ${GIT_BRANCH}"
#echo "'${RAW_LAST_TAG:-}' -${FIRST_PART_LAST_TAG}- -${LAST_PART_LAST_TAG}-"
#echo "${NEXT_TAG} ${PRE_RELEASE_SUFFIX} ${COMMIT_COUNT}"

# These are python compliant
#echo "${CUR_VERSION}"
echo "${LONG_FORM_CUR_VERSION}"

export CUR_VERSION
export LONG_FORM_CUR_VERSION

# TODO: give deb compliant version option
