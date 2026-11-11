# Changelog

Release notes and notable changes for `github.com/neurono-ml/sciencekit-go` follow [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

- **Go bindings changelog:** [`CHANGELOG.md` on GitHub](https://github.com/neurono-ml/sciencekit-go/blob/main/CHANGELOG.md)
- **GitHub Releases:** [`neurono-ml/sciencekit-go/releases`](https://github.com/neurono-ml/sciencekit-go/releases)
- **Upstream Rust core & `sciencekit_ffi` changelog:** [`neurono-ml/sciencekit` `CHANGELOG.md`](https://github.com/neurono-ml/sciencekit/blob/main/CHANGELOG.md)

## Highlights (Unreleased)

### Added

- Standalone Go module `github.com/neurono-ml/sciencekit-go` extracted from `neurono-ml/sciencekit`, wrapping `sciencekit_ffi` ABI v1 via `cgo`.
- Generic dense `Matrix[T]` (`Float` constraint `~float32 | ~float64`, including named float types) and C-owned `SKFfiArray` descriptor conversion verified under `GOEXPERIMENT=cgocheck2`.
- `LinearRegressionBuilder[T]` and `LinearRegressionModel[T]` supporting `IncludeIntercept`, `Backend`, `Fit`, `Predict`, `Score`, `Save`, and `LoadLinearRegression`.
- `StandardScalerBuilder[T]` and `StandardScalerModel[T]` supporting `WithMean`, `WithStd`, `Backend`, `Fit`, and `Transform`.
- Structured `*ScienceKitError` diagnostics (`Operation`, `Code`, `Message`), `Status` constants, and `IsStatus(err, status)`.
- Concurrency-safe handles (`sync.Mutex` on builders, `sync.RWMutex` on models) with idempotent `Close()` and `runtime.SetFinalizer` backup.
- Helper scripts `scripts/build-native-library.sh` and `scripts/sync-header.sh`, runnable examples under `examples/`, and this mdBook documentation site.
