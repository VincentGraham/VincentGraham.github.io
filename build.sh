#!/bin/bash
set -e

# Clean previous build
rm -rf dist
mkdir dist

# Copy and optimize content
cp index.html dist/
# cp -r images/ dist/images/

# You can add minifiers, image compression, etc.

echo "Build complete."