#!/bin/bash
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PATCH_DIR="$SCRIPT_DIR/../patches/SPIRV-Cross"
CROSS_ROOT=$1

for CROSS_PATCH in "$PATCH_DIR/"*.patch; do
    if git -C "$CROSS_ROOT" apply --reverse --check "$CROSS_PATCH" >/dev/null 2>&1; then
        :
    elif git -C "$CROSS_ROOT" apply --check "$CROSS_PATCH" >/dev/null 2>&1; then
        git -C "$CROSS_ROOT" apply "$CROSS_PATCH"
    else
        echo "SPIRV-Cross patch $CROSS_PATCH does not apply to $CROSS_ROOT" >&2
        exit 1
    fi
done
