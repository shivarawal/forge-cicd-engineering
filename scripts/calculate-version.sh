#!/usr/bin/env bash

set -euo pipefail

TAG_PREFIX="v"

echo "======================================"
echo " Forge Release Version Calculator"
echo "======================================"

# Find latest semantic-version tag.
LATEST_TAG=$(
  git tag --sort=-v:refname |
  grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+$" |
  head -1
)

if [[ -z "${LATEST_TAG}" ]]; then
  echo "ERROR: No semantic version tag found."
  exit 1
fi

echo "Latest release: ${LATEST_TAG}"

# Remove tag prefix.
CURRENT_VERSION="${LATEST_TAG#${TAG_PREFIX}}"

IFS='.' read -r MAJOR MINOR PATCH <<< "${CURRENT_VERSION}"

echo "Current version: ${MAJOR}.${MINOR}.${PATCH}"

# Get commits after latest release.
COMMITS=$(git log "${LATEST_TAG}..HEAD" --pretty=format:"%B")

echo
echo "Commits since ${LATEST_TAG}:"

if [[ -z "${COMMITS}" ]]; then
  echo "No new commits."
  echo "${CURRENT_VERSION}"
  exit 0
fi

echo "${COMMITS}"

# Determine version bump.
BUMP="none"

while IFS= read -r COMMIT; do

  # BREAKING CHANGE or conventional commit with !.
  if [[ "${COMMIT}" =~ BREAKING[[:space:]]CHANGE ]] ||
     [[ "${COMMIT}" =~ ^[a-zA-Z]+(\(.+\))?!: ]]; then
    BUMP="major"
    break
  fi

  # Feature commit.
  if [[ "${COMMIT}" =~ ^feat(\(.+\))?: ]] &&
     [[ "${BUMP}" != "major" ]]; then
    BUMP="minor"
    continue
  fi

  # Patch-level commits.
  if [[ "${COMMIT}" =~ ^(fix|perf|refactor)(\(.+\))?: ]] &&
     [[ "${BUMP}" == "none" ]]; then
     BUMP="patch"
  fi

done <<< "${COMMITS}"

echo
echo "Detected bump: ${BUMP}"

case "${BUMP}" in

  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;

  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;

  patch)
    PATCH=$((PATCH + 1))
    ;;

  none)
    echo "No release-worthy Conventional Commit found."
    echo "${CURRENT_VERSION}"
    exit 0
    ;;

esac

NEXT_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo
echo "Next version: ${NEXT_VERSION}"
echo "Release tag: ${TAG_PREFIX}${NEXT_VERSION}"

# GitHub Actions output support.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "version=${NEXT_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "tag=${TAG_PREFIX}${NEXT_VERSION}" >> "${GITHUB_OUTPUT}"
  echo "bump=${BUMP}" >> "${GITHUB_OUTPUT}"
fi
