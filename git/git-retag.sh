#!/usr/bin/env bash
# recreate a tog on a new commit
#
# Usage: ./git-retag.sh versiontag "desc"
set -euo pipefail

TAG="${1:-}"
MSG="${2:-}"

if [[ -z "$TAG" || -z "$MSG" ]]; then
  echo "Usage: $0 <tag-name> \"<tag-message>\""
  exit 1
fi

echo "[GIT-RETAG] Retagging $TAG with message: $MSG"

# 1. Delete local tag if exists
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "[GIT-RETAG]] Deleting local tag $TAG"
  git tag -d "$TAG"
fi

# 2. Delete remote tag if exists
if git ls-remote --tags origin | grep -q "refs/tags/$TAG"; then
  echo "[GIT-RETAG]] Deleting remote tag $TAG"
  git push origin ":refs/tags/$TAG"
fi

# 3. Create new annotated tag
echo "[GIT-RETAG]] Creating new tag $TAG"
git tag -a "$TAG" -m "$MSG"

# 4. Push tag to origin
echo "[GIT-RETAG]] Pushing tag $TAG to origin"
git push origin "$TAG"

echo "[GIT-RETAG] [OK] Tag $TAG recreated successfully."
