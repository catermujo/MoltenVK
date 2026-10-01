#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
CROSS="$ROOT/External/SPIRV-Cross"
SLANG="$ROOT/../slang/build/Release/bin/slangc"
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/mvk-reserved-names.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

make -C "$CROSS" -j4 >/dev/null
"$SLANG" "$SCRIPT_DIR/temporary_names.slang" -entry main -stage compute \
    -target spirv -profile spirv_1_5 -O0 -g1 -o "$BUILD/temporary_names.spv"
clang++ -std=c++11 -fobjc-arc -Wall -Wextra \
    -DSPIRV_CROSS_SPV_HEADER_NAMESPACE_OVERRIDE=spv_private \
    -I"$CROSS" "$SCRIPT_DIR/reserved_names_test.mm" "$CROSS/libspirv-cross.a" \
    -framework Foundation -framework Metal -o "$BUILD/reserved_names_test"
"$BUILD/reserved_names_test" "$BUILD/temporary_names.spv"
