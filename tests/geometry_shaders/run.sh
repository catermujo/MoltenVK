#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
CROSS="$ROOT/External/SPIRV-Cross"
BUILD=$(mktemp -d "${TMPDIR:-/tmp}/mvk-geometry-test.XXXXXX")
trap 'rm -rf "$BUILD"' EXIT

make -C "$CROSS" -j4 >/dev/null

c++ -std=c++11 -Wall -Wextra \
    -DSPIRV_CROSS_SPV_HEADER_NAMESPACE_OVERRIDE=spv_private \
    -I"$CROSS" \
    "$SCRIPT_DIR/geometry_msl_test.cpp" "$CROSS/libspirv-cross.a" \
    -o "$BUILD/geometry_msl_test"

compile_geometry() {
	name=$1
	topology=$2
	glslc -fshader-stage=geom \
		-o "$BUILD/$name.spv" "$SCRIPT_DIR/$name.geom"
	"$BUILD/geometry_msl_test" "$BUILD/$name.spv" "$BUILD/$name.msl" "$topology"
	(
		printf '%s\n' \
			'#define __HAVE_MESH__ 1' \
			'#define __HAVE_RENDER_COMMAND_MESH__ 1' \
			'#include <metal_stdlib>' \
			'#include <simd/simd.h>'
		sed -n '4,$p' "$BUILD/$name.msl"
	) | xcrun -sdk macosx metal -x metal -std=metal3.0 -fno-modules \
		-Werror -Wno-unused-variable -c -o "$BUILD/$name.air" -
}

compile_geometry geometry_point points
compile_geometry geometry_line lines
compile_geometry geometry_triangle triangles
compile_geometry geometry_builtins triangles
compile_geometry geometry_triangle_adjacency triangles-adjacency
compile_geometry geometry_multi_invocation triangles

echo "geometry shader mesh lowering tests passed"
