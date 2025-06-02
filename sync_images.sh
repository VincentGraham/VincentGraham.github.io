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

# 4. Remove macOS artifacts (.DS_Store, AppleDouble files) from the temp copy
echo "⏳ Removing macOS hidden files from temp copy..."
find "$TMP_DIR" -type f \( -name ".DS_Store" -o -name "._*" \) -delete

# 5. Stash any uncommitted changes in source (to allow a clean checkout)
git add -A
git stash push -m "temp-stash-before-updating-images" || true

# 6. Checkout main branch
echo "⏳ Checking out '$MAIN_BRANCH'..."
git checkout "$MAIN_BRANCH"
git pull origin "$MAIN_BRANCH" --rebase

# 7. Prepare target folder on main (create if missing)
echo "⏳ Ensuring '$IMAGES_PATH' exists on '$MAIN_BRANCH'..."
mkdir -p "$IMAGES_PATH"

# 8. Copy from temporary folder into main’s images path
echo "⏳ Moving images from temp → '$IMAGES_PATH'..."
rsync -a --delete "$TMP_DIR"/ "$IMAGES_PATH"/

# 9. Stage & commit any changes
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

# 10. Clean up temp folder
echo "⏳ Removing temporary folder '$TMP_DIR'..."
rm -rf "$TMP_DIR"

# 11. Checkout back to source and pop stash
echo "⏳ Switching back to 'source'..."
git checkout source

if git stash list | grep -q "temp-stash-before-updating-images"; then
  echo "⏳ Restoring any stashed changes on 'source'..."
  git stash pop || true
fi

echo "✅ Images (and thumbnails) synced to '$MAIN_BRANCH' successfully."