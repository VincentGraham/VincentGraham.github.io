#!/usr/bin/env bash
set -euo pipefail

# ───────── CONFIG ─────────
IMAGES_PATH="3dgs/images"
MAIN_BRANCH="main"
# ──────────────────────────

# 1. Verify we’re on the source branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "source" ]]; then
  echo "❌ ERROR: Run this from the 'source' branch (currently on '$CURRENT_BRANCH')."
  exit 1
fi

# 2. Check that the IMAGES_PATH directory exists locally on source
if [[ ! -d "$IMAGES_PATH" ]]; then
  echo "❌ ERROR: '$IMAGES_PATH' not found. Create it (with full-res + thumbs) before running."
  exit 1
fi

# 3. Create a temporary directory to hold images
TMP_DIR=$(mktemp -d)
echo "⏳ Copying '$IMAGES_PATH' → temporary folder '$TMP_DIR'..."
rsync -a "$IMAGES_PATH"/ "$TMP_DIR"/

# 4. Stash any uncommitted changes in source (to allow a clean checkout)
git add -A
git stash push -m "temp-stash-before-updating-images" || true

# 5. Checkout main branch
echo "⏳ Checking out '$MAIN_BRANCH'..."
git checkout "$MAIN_BRANCH"

# 5.5. Pull latest changes from main
echo "⏳ Pulling latest changes from '$MAIN_BRANCH'..."
git pull origin "$MAIN_BRANCH"

# 6. Prepare target folder on main (create if missing)
echo "⏳ Ensuring '$IMAGES_PATH' exists on '$MAIN_BRANCH'..."
mkdir -p "$IMAGES_PATH"

# 7. Copy from temporary folder into main’s images path
echo "⏳ Moving images from temp → '$IMAGES_PATH'..."
rsync -a --delete "$TMP_DIR"/ "$IMAGES_PATH"/

# 8. Stage & commit any changes
cd "$IMAGES_PATH/.."
git add "$(basename "$IMAGES_PATH")"
if git diff --cached --quiet; then
  echo "ℹ️  No image changes to commit on '$MAIN_BRANCH'."
else
  echo "⏳ Committing updated images to '$MAIN_BRANCH'..."
  git commit -m "Sync full-res images & thumbnails into $IMAGES_PATH"
  echo "⏳ Pushing to '$MAIN_BRANCH'..."
  git push origin "$MAIN_BRANCH"
fi

# 9. Clean up temp folder
echo "⏳ Removing temporary folder '$TMP_DIR'..."
rm -rf "$TMP_DIR"

# 10. Checkout back to source and pop stash
echo "⏳ Switching back to 'source'..."
git checkout source

if git stash list | grep -q "temp-stash-before-updating-images"; then
  echo "⏳ Restoring any stashed changes on 'source'..."
  git stash pop || true
fi

echo "✅ Images (and thumbnails) synced to '$MAIN_BRANCH' successfully."