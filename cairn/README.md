# Cairn compilation experiments

This branch starts at Rust 1.97.1's exact LLVM submodule commit,
`dcc3606807c989700e0ac1cac18c31741bcd40d9`.

The initial source experiment avoids GlobalOpt's cold-call scan on modules where
no defined function's target requests that calling convention. The original
scan is preserved for targets that use it and for the stress-testing option.
The target query deliberately excludes declarations: intrinsic declarations may
not be passed to TargetIRAnalysis.

The regression tests cover x86, PowerPC's positive coldcc path, and the existing
debug-information consistency scenario. Performance and whole-program correctness
must be assessed separately; fewer analysis requests alone are not a speedup.

## Independent source-pass replay

`build-globalopt-plugin.mjs` builds both the original and patched GlobalOpt source
with the same C++ compiler and options. It gives each pass a distinct class name,
pipeline token, debug category and private command-line option names. Both plugins
link against one explicitly selected, matching LLVM shared library. This avoids
rebuilding the entire compiler merely to test the source-level hypothesis.

Configure the matching LLVM source and generate its intrinsic headers first:

```sh
cmake -S llvm -B /absolute/llvm-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=X86 \
  -DLLVM_INCLUDE_TESTS=OFF -DLLVM_ENABLE_RTTI=OFF
ninja -C /absolute/llvm-build intrinsics_gen

node cairn/build-globalopt-plugin.mjs \
  --llvm-build /absolute/llvm-build \
  --llvm-dylib /absolute/matching/libLLVM.so \
  --out /absolute/plugins

/absolute/matching/opt \
  -load-pass-plugin=/absolute/plugins/cairn-globalopt-reference.so \
  -passes=cairn-globalopt-reference -verify-each input.bc -o reference.bc
/absolute/matching/opt \
  -load-pass-plugin=/absolute/plugins/cairn-globalopt-patched.so \
  -passes=cairn-globalopt-patched -verify-each input.bc -o patched.bc
```

Use the preserved, unoptimized Cairn module from the exact application commit.
Compare both pass-only and complete prelink pipelines, repeat in shuffled order
under the same CPU affinity, and record input/tool/plugin/output hashes, elapsed
time, CPU, peak memory and generated size. Verify every output. A verifier pass
checks IR validity; it does not prove semantic equivalence.

Loading this parser-only plugin in rustc does not replace its default GlobalOpt
passes. For normal placement, build the native modified LLVM and a matching Rust
compiler. A generic LLVM shared library must not be installed over the Rust
distribution's library. Keep the experimental compiler isolated and run Cairn's
release tests and runtime/storage benchmarks before using its output in production.
