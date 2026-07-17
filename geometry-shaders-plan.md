# Geometry shaders

Baseline: `52e9e092` (`MoltenVK: port geometry shaders`).

Scope: make the js6i geometry-shader port truthful, usable, and testable on
macOS with Xcode 14+/MSL 3.0. Older platforms must report unsupported rather
than expose a feature that cannot compile. Unsupported Vulkan stage
combinations must fail explicitly.

## Milestones

1. **Capability contract** — gate geometry support on compile-time and runtime
   Metal support; expose matching features and limits; reject unsupported
   stage combinations. Verify with feature/limit queries and negative pipeline
   creation tests.
2. **SPIRV-Cross geometry lowering** — support declared input/output
   topologies, primitive counts, interface built-ins, and geometry limits.
   Verify generated MSL golden files and SPIRV-Cross shader tests.
3. **Pipeline integration** — pass geometry metadata through mesh pipeline
   descriptors, reject tessellation and multiview combinations that the
   lowering cannot represent, and verify pipeline creation for supported and
   negative combinations.
4. **Draw commands** — support direct, indexed, indirect, and indexed-indirect
   mesh dispatch, including vertex/index/instance offsets. Geometry plus
   multiview remains explicitly unsupported by the advertised Vulkan feature.
   Verify rendered output for each supported draw path.
5. **Runtime test harness** — add deterministic SPIR-V-to-MSL and Metal AIR
   compilation tests. Cover point, line, triangle, strip, built-ins, offsets,
   indirect lowering, and negative cases; add offscreen MoltenVK readback when
   the host build can link the full runtime.
6. **Regression and cleanup** — run package builds, SPIRV-Cross tests, runtime
   tests, and existing regressions; remove debug diagnostics; export the
   SPIRV-Cross patch; commit each milestone.

Current phase: Phase 3 — Verify.
