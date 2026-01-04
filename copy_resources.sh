#!/bin/bash
set -e

DEST="${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}"
SRC="${SRCROOT}/Resources"

mkdir -p "${DEST}"

# Base track (also expose as "track 3" to match metadata)
cp "${SRCROOT}/Resources.bundle/track.wav" "${DEST}/track.wav"
cp "${SRC}/track.wav" "${DEST}/track 3.wav"

# Charts
cp "${SRC}/chart.json" "${DEST}/chart.json"
cp "${SRC}/crazy_train.json" "${DEST}/crazy_train.json"
cp "${SRC}/day_n_nite.json" "${DEST}/day_n_nite.json"

# Audio
cp "${SRC}/crazy_train.mp3" "${DEST}/crazy_train.mp3"
cp "${SRC}/day_n_nite.mp3" "${DEST}/day_n_nite.mp3"

# Visuals
cp "${SRC}/revenge_overlay.png" "${DEST}/revenge_overlay.png"

echo "Copied resources to app bundle"
