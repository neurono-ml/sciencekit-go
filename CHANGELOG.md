# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Standalone `github.com/neurono-ml/sciencekit-go` module wrapping the `sciencekit_ffi` C ABI (`v1`) via `cgo`.
- Generic `Matrix[T]` (`~float32 | ~float64`) with shape validation and C-owned `SKFfiArray` copies compliant with `GOEXPERIMENT=cgocheck2`.
- `LinearRegressionBuilder[T]`, `LinearRegressionModel[T]`, and `LoadLinearRegression` (`IncludeIntercept`, `Backend`, `Fit`, `Predict`, `Score`, `Save`).
- `StandardScalerBuilder[T]` and `StandardScalerModel[T]` (`WithMean`, `WithStd`, `Backend`, `Fit`, `Transform`).
- Structured error handling (`ScienceKitError`, `Status`, `IsStatus`) and ABI version/capability introspection (`Version`, `Features`, `HasFeature`).
- Concurrency-safe handle management (`Close` + `runtime.SetFinalizer`) and helper scripts (`scripts/build-native-library.sh`, `scripts/sync-header.sh`).
- English mdBook documentation site published to GitHub Pages (`https://neurono-ml.github.io/sciencekit-go/`).
