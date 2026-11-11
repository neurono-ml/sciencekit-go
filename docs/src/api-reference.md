# API Reference

Complete reference of every exported symbol in package `sciencekit` (`github.com/neurono-ml/sciencekit-go`), grounded directly in the source files (`types.go`, `version.go`, `errors.go`, `builders.go`, `models.go`, and `persistence.go`).

```go
import sciencekit "github.com/neurono-ml/sciencekit-go"
```

---

## ABI Version and Feature Discovery (`version.go`)

### `VersionInfo`

```go
type VersionInfo struct {
	Major int32
	Minor int32
	Patch int32
}
```

Semantic version of the loaded `sciencekit_ffi` C ABI. `sciencekit-go` requires `Major == 1`.

### Feature Bitmask Constants

```go
const (
	FeatureLinearRegression uint64 = 1 << 0
	FeatureStandardScaler   uint64 = 1 << 1
	FeatureModelPersistence uint64 = 1 << 2
	FeatureF32              uint64 = 1 << 3
	FeatureF64              uint64 = 1 << 4
)
```

### `Version`

```go
func Version() (VersionInfo, error)
```

Returns the ABI version of the loaded native library captured at package `init()`. Returns a `*ScienceKitError` with `StatusUnsupported` (`Operation: "abi_version"`) if `Major != 1`, or any status error returned by `sk_ffi_version`.

### `Features`

```go
func Features() uint64
```

Reads the capability bitmask reported by `sk_ffi_features()` in the loaded native library.

### `HasFeature`

```go
func HasFeature(flag uint64) bool
```

Reports whether every bit in `flag` is set in `Features()` (`Features()&flag == flag`).

---

## Scalar Constraints, Backends, and Dense Matrices (`types.go`)

### `Float`

```go
type Float interface {
	~float32 | ~float64
}
```

Type constraint for all generic matrix, builder, and model types. Accepts `float32`, `float64`, and user-defined named types whose underlying type is `float32` or `float64`.

### `BackendKind`

```go
type BackendKind int32

const (
	BackendFaer           BackendKind = 0
	BackendMatrixMultiply BackendKind = 1
	BackendNdArrayLinalg  BackendKind = 2
)
```

Selects the linear-algebra backend executed by the Rust core (`Faer` is the default). Passing any other integer value to a builder's `Backend` method returns `*ScienceKitError` with `StatusInvalidArgument`.

### `Matrix[T]` and `NewMatrix`

```go
type Matrix[T Float] struct {
	Rows    int
	Columns int
	Data    []T
}

func NewMatrix[T Float](rows, columns int, data []T) (Matrix[T], error)
```

`Matrix[T]` is a dense row-major matrix (`Data[row*Columns + column]`). `NewMatrix` borrows `data` without copying and validates `rows > 0`, `columns > 0`, and `len(data) == rows*columns`, returning `StatusInvalidArgument` (`Operation: "new_matrix"`) on failure.

---

## Errors and Status Codes (`errors.go`)

### `Status`

```go
type Status int32

const (
	StatusUnknown         Status = -1
	StatusOK              Status = 0
	StatusInvalidHandle   Status = 1
	StatusShape           Status = 2
	StatusInvalidArgument Status = 3
	StatusUnsupported     Status = 4
	StatusNotFitted       Status = 5
	StatusIO              Status = 6
	StatusInternal        Status = 7
)

func (status Status) Name() string
func (status Status) String() string
```

`Status` represents a `sciencekit_ffi` status code (plus `StatusUnknown = -1` for pointer-returning FFI calls that report diagnostics via `sk_ffi_last_error()`). `Name()` and `String()` return the stable lowercase status name (`"unknown"`, `"ok"`, `"invalid-handle"`, `"shape"`, `"invalid-argument"`, `"unsupported"`, `"not-fitted"`, `"io"`, `"internal"`).

### `ScienceKitError`

```go
type ScienceKitError struct {
	Operation string
	Code      Status
	Message   string
}

func (errorValue *ScienceKitError) Error() string
```

Concrete error returned by every failing function or method in `sciencekit-go`.

### `IsStatus`

```go
func IsStatus(err error, status Status) bool
```

Reports whether `err` unwraps (`errors.As`) to a `*ScienceKitError` whose `Code == status`. Safely returns `false` for `nil` or unrelated errors.

---

## Linear Regression (`builders.go`, `models.go`, `persistence.go`)

### `LinearRegressionBuilder[T]`

```go
type LinearRegressionBuilder[T Float] struct {
	// contains filtered or unexported fields
}

func NewLinearRegressionBuilder[T Float]() (*LinearRegressionBuilder[T], error)
func (builder *LinearRegressionBuilder[T]) IncludeIntercept(enabled bool) error
func (builder *LinearRegressionBuilder[T]) Backend(kind BackendKind) error
func (builder *LinearRegressionBuilder[T]) Fit(features Matrix[T], targets []T) (*LinearRegressionModel[T], error)
func (builder *LinearRegressionBuilder[T]) Close() error
```

- **`NewLinearRegressionBuilder[T]()`** — verifies ABI compatibility, creates a native linear-regression builder configured with defaults (`IncludeIntercept(true)`, `BackendFaer`), and registers a cleanup finalizer.
- **`IncludeIntercept(enabled bool) error`** — chooses whether ordinary least squares solves for an intercept term.
- **`Backend(kind BackendKind) error`** — validates and sets the math backend (`BackendFaer`, `BackendMatrixMultiply`, or `BackendNdArrayLinalg`).
- **`Fit(features Matrix[T], targets []T) (*LinearRegressionModel[T], error)`** — validates `features` and `len(targets) == features.Rows`, copies inputs into temporary C-owned descriptors, trains the model, and returns a concurrency-safe `*LinearRegressionModel[T]`.
- **`Close() error`** — idempotently releases the native builder handle.

### `LinearRegressionModel[T]`

```go
type LinearRegressionModel[T Float] struct {
	// contains filtered or unexported fields
}

func (model *LinearRegressionModel[T]) Predict(features Matrix[T]) ([]T, error)
func (model *LinearRegressionModel[T]) Score(features Matrix[T], targets []T) (float64, error)
func (model *LinearRegressionModel[T]) Save(path string) error
func (model *LinearRegressionModel[T]) Close() error
```

- **`Predict(features Matrix[T]) ([]T, error)`** — returns one predicted response value per row in `features` as a fresh `[]T` slice.
- **`Score(features Matrix[T], targets []T) (float64, error)`** — computes the `R²` coefficient of determination on `(features, targets)`.
- **`Save(path string) error`** — writes the interop state file to `path` (supported for `LinearRegressionModel[float64]`; returns `StatusUnsupported` for `float32` and `StatusInvalidArgument` when `path == ""`).
- **`Close() error`** — idempotently releases the native model handle.

### `LoadLinearRegression`

```go
func LoadLinearRegression(path string) (*LinearRegressionModel[float64], error)
```

Loads a fitted double-precision `LinearRegressionModel[float64]` previously saved with `Save` (or exported by the Rust core / another `sciencekit_ffi` binding). Rejects `path == ""` with `StatusInvalidArgument`.

---

## Standard Scaler (`builders.go`, `models.go`)

### `StandardScalerBuilder[T]`

```go
type StandardScalerBuilder[T Float] struct {
	// contains filtered or unexported fields
}

func NewStandardScalerBuilder[T Float]() (*StandardScalerBuilder[T], error)
func (builder *StandardScalerBuilder[T]) WithMean(enabled bool) error
func (builder *StandardScalerBuilder[T]) WithStd(enabled bool) error
func (builder *StandardScalerBuilder[T]) Backend(kind BackendKind) error
func (builder *StandardScalerBuilder[T]) Fit(features Matrix[T]) (*StandardScalerModel[T], error)
func (builder *StandardScalerBuilder[T]) Close() error
```

- **`NewStandardScalerBuilder[T]()`** — verifies ABI compatibility, creates a native standard-scaler builder with defaults (`WithMean(true)`, `WithStd(true)`, `BackendFaer`), and registers a cleanup finalizer.
- **`WithMean(enabled bool) error`** — enables or disables per-column mean centering.
- **`WithStd(enabled bool) error`** — enables or disables division by per-column standard deviation.
- **`Backend(kind BackendKind) error`** — validates and sets the math backend.
- **`Fit(features Matrix[T]) (*StandardScalerModel[T], error)`** — computes per-column statistics over `features` and returns an immutable `*StandardScalerModel[T]`.
- **`Close() error`** — idempotently releases the native builder handle.

### `StandardScalerModel[T]`

```go
type StandardScalerModel[T Float] struct {
	// contains filtered or unexported fields
}

func (model *StandardScalerModel[T]) Transform(features Matrix[T]) (Matrix[T], error)
func (model *StandardScalerModel[T]) Save(path string) error
func (model *StandardScalerModel[T]) Close() error
```

- **`Transform(features Matrix[T]) (Matrix[T], error)`** — standardizes `features` using the fitted statistics and returns a fresh `Matrix[T]`.
- **`Save(path string) error`** — validates `path != ""` (`StatusInvalidArgument`) and delegates to `sk_ffi_model_save`, which currently returns `StatusUnsupported` for scaler models.
- **`Close() error`** — idempotently releases the native model handle.
