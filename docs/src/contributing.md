# Contributing

Contributions to [`neurono-ml/sciencekit-go`](https://github.com/neurono-ml/sciencekit-go) are welcome! Because this repository is a thin, idiomatic Go layer over `sciencekit_ffi`, changes stay focused on Go type safety, `cgo` correctness, concurrency guarantees, tests, and documentation.

## Repository Layout

| Path | Responsibility |
| --- | --- |
| `include/sciencekit.h` | Vendored C ABI header synced from `neurono-ml/sciencekit` (`scripts/sync-header.sh`) |
| `types.go` | `Float`, `BackendKind`, `Matrix[T]`, `NewMatrix`, Go-side shape/backend validation |
| `arrays.go` | Conversions between `Matrix[T]` / `[]T` and C-owned `SKFfiArray` descriptors |
| `cgo.go` | `cgo` directives, descriptor memory management, `nativeBuilder`, thread-locked status helpers |
| `native_model.go` | Thread-locked `fit`, `predict`, `transform`, `score`, `save`, and `loadNativeModel` calls |
| `builders.go` | `LinearRegressionBuilder[T]` and `StandardScalerBuilder[T]` (`sync.Mutex` + finalizer) |
| `models.go` | `LinearRegressionModel[T]` and `StandardScalerModel[T]` (`sync.RWMutex` + finalizer) |
| `persistence.go` | `LoadLinearRegression` |
| `errors.go` | `Status`, `ScienceKitError`, `IsStatus` |
| `lifecycle.go` | Atomic live-handle counters backing leak and finalizer tests |
| `version.go` | `VersionInfo`, `Feature*` flags, `Version()`, `Features()`, `HasFeature()` |
| `*_test.go` | Companion unit, example, concurrency, lifecycle, persistence, and large-matrix tests |
| `examples/` | Runnable CLI programs (`linearregression`, `standardscaler`) |
| `docs/` | This mdBook documentation site (maintained on branch `docs/documentations`) |

## Local Development Setup

Clone `neurono-ml/sciencekit` alongside `neurono-ml/sciencekit-go`, build the native library, and run all CI gates locally before opening a pull request:

```sh
# 1. Build and install libsciencekit_ffi into ./lib/
scripts/build-native-library.sh ../sciencekit

# 2. Keep the vendored C header in sync
scripts/sync-header.sh ../sciencekit

# 3. Formatting and static analysis
test -z "$(gofmt -l .)"
go vet ./...

# 4. Standard, race-detector, and strict cgo pointer test suites
go test ./...
go test -race ./...
GOEXPERIMENT=cgocheck2 go test ./...
```

## Coding Rules

1. **Everything durable is written in English** — code, comments, commit messages, pull requests, issues, and documentation chapters.
2. **Never store a Go pointer in C memory.** Any buffer referenced inside a C struct must be allocated on the C heap (`C.malloc` / `C.calloc`) and freed deterministically, and every change must pass `GOEXPERIMENT=cgocheck2 go test ./...`.
3. **Lock OS threads around thread-local FFI diagnostics.** Any C call that reads `sk_ffi_last_error()` on failure must run inside `runtime.LockOSThread()` / `defer runtime.UnlockOSThread()`.
4. **Test-first discipline.** Add tests in the matching `*_test.go` file (`operations_test.go`, `errors_test.go`, `lifecycle_test.go`, `concurrency_test.go`, `arrays_test.go`, `persistence_test.go`) covering success paths, error codes (`IsStatus`), and handle release (`openHandleCounts`).

## Working on Documentation

Documentation lives on the `docs/documentations` branch and deploys automatically to GitHub Pages via `.github/workflows/deploy-documentation.yml`:

```sh
mdbook build docs
node docs/scripts/postbuild.mjs
mdbook serve docs --open
```

## License

Apache License 2.0 — see [`LICENSE`](https://github.com/neurono-ml/sciencekit-go/blob/main/LICENSE).
