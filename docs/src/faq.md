# Frequently Asked Questions

## Why does `go build` or `go test` fail with `cannot find -lsciencekit_ffi`?

`sciencekit-go` links dynamically against the native `sciencekit_ffi` shared library compiled from the main [`neurono-ml/sciencekit`](https://github.com/neurono-ml/sciencekit) repository. Either run:

```sh
scripts/build-native-library.sh /path/to/sciencekit
```

to build and install the shared object into `lib/`, or export `CGO_CFLAGS`, `CGO_LDFLAGS`, and `LD_LIBRARY_PATH` (`DYLD_LIBRARY_PATH` on macOS) pointing at an existing `target/release` directory. See [Installation](installation.md) for platform-specific commands.

## Why does `sciencekit-go` copy slices into `C.malloc` instead of passing `&slice[0]`?

Go's `cgo` pointer rules forbid storing any Go pointer inside C-allocated memory (`SKFfiArray.data` and `SKFfiArray.shape` live inside a C descriptor struct). Even `runtime.KeepAlive` does not make storing a Go pointer in C memory legal under `GOEXPERIMENT=cgocheck2`. Copying into temporary C-owned buffers keeps the binding 100% compliant with `cgocheck2` and lets the Go garbage collector move or collect caller slices freely.

## Is a fitted model safe to share across HTTP or gRPC request goroutines?

Yes. `LinearRegressionModel[T]` and `StandardScalerModel[T]` are immutable once fitted and coordinate concurrent `Predict`, `Score`, `Transform`, and `Save` calls with an internal `sync.RWMutex` read lock (`RLock`). Multiple goroutines execute inference in parallel without external locking. See [Concurrency Safety](guides/concurrency.md).

## What happens if I forget to call `Close()`?

Every builder and model registers a `runtime.SetFinalizer` on creation that calls `Close()` if the Go wrapper is garbage-collected before being closed explicitly. However, because Go's garbage collector cannot see the size of native Rust allocations, deterministic production code should always `defer builder.Close()` and `defer model.Close()`. Calling `Close()` multiple times is a safe no-op.

## Why does `scaler.Save(path)` or `float32Model.Save(path)` return `StatusUnsupported`?

In `sciencekit_ffi` ABI v1, the native state persistence container currently covers fitted double-precision (`float64`) linear-regression models (`LinearRegressionModel[float64]`). Saving a `StandardScalerModel` or `LinearRegressionModel[float32]` cleanly surfaces `StatusUnsupported` (`IsStatus(err, sciencekit.StatusUnsupported) == true`).

## Why do `Fit` failures sometimes report `StatusUnknown` (`-1`)?

In `sciencekit.h`, `sk_ffi_fit` returns an opaque `*SKFfiModel` pointer (`NULL` on failure) rather than an integer `SKFfiStatus`. When `sk_ffi_fit` returns `NULL`, `sciencekit-go` sets `Code: StatusUnknown` (`-1`) and populates `ScienceKitError.Message` from the thread-local `sk_ffi_last_error()` slot on the locked OS thread. Go-side pre-flight checks (such as malformed matrices or mismatched target lengths) run *before* `sk_ffi_fit` and report `StatusInvalidArgument`.

## Can I cross-compile or build with `CGO_ENABLED=0`?

`CGO_ENABLED=1` is required because `sciencekit-go` invokes `sciencekit_ffi` via `cgo`. Cross-compilation works when you supply a C cross-compiler (`CC=...`) and build `sciencekit_ffi` for the same target triple (`cargo build -p sciencekit_ffi --release --target <triple>`).
