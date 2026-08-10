#!/usr/bin/env bash

set -euo pipefail

echo "======================================"
echo " Forge Release Manager"
echo "======================================"

# --------------------------------------------------
# Validate working tree
# --------------------------------------------------

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: Working tree is not clean."
  echo
  git status --short
  exit 1
fi

echo "Working tree: clean"

# --------------------------------------------------
# Calculate next version
# --------------------------------------------------

echo
echo "Calculating next version..."

VERSION_OUTPUT=$(./scripts/calculate-version.sh)

LATEST_TAG=$(
  git tag --sort=-v:refname |
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
  head -1
)

echo
echo "${VERSION_OUTPUT}"

NEXT_VERSION=$(echo "${VERSION_OUTPUT}" |
  awk '/^Next version:/ {print $3}')

NEXT_TAG=$(echo "${VERSION_OUTPUT}" |
  awk '/^Release tag:/ {print $3}')

if [[ -z "${NEXT_VERSION}" || -z "${NEXT_TAG}" ]]; then
  echo
  echo "ERROR: No release required."
  echo "The current commits do not contain a release-worthy change."
  exit 0
fi

echo
echo "======================================"
echo " Release Information"
echo "======================================"
echo "Previous Release : ${LATEST_TAG}"
echo "Version          : ${NEXT_VERSION}"
echo "Tag              : ${NEXT_TAG}"
echo "======================================"

# --------------------------------------------------
# Update VERSION
# --------------------------------------------------

echo
echo "Updating VERSION..."

printf '%s\n' "${NEXT_VERSION}" > VERSION

echo "VERSION updated to ${NEXT_VERSION}"

# --------------------------------------------------
# Generate CHANGELOG entry
# --------------------------------------------------

echo
echo "Updating CHANGELOG.md..."

DATE=$(date +%Y-%m-%d)

TEMP_CHANGELOG=$(mktemp)

{
  echo "# Changelog"
  echo
  echo "## ${NEXT_VERSION} - ${DATE}"
  echo
  echo "### Changes"
  echo

  # IMPORTANT:
  # Use the previous release tag because NEXT_TAG
  # does not exist yet.
  git log "${LATEST_TAG}..HEAD" \
    --pretty=format:"- %s"

  echo
  echo
  tail -n +2 CHANGELOG.md
} > "${TEMP_CHANGELOG}"

mv "${TEMP_CHANGELOG}" CHANGELOG.md

echo "CHANGELOG updated."

# --------------------------------------------------
# Show release changes
# --------------------------------------------------

echo
echo "======================================"
echo " Release Changes"
echo "======================================"

git diff -- VERSION CHANGELOG.md

echo
echo "======================================"
echo " Release preparation complete"
echo "======================================"
echo
echo "Next steps:"
echo "  git add VERSION CHANGELOG.md"
echo "  git commit -m \"chore(release): ${NEXT_TAG}\""
echo "  git tag -a ${NEXT_TAG} -m \"Release ${NEXT_TAG}\""
echo "  git push origin main"
echo "  git push origin ${NEXT_TAG}"
