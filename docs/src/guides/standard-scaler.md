# Standard Scaler

`StandardScalerBuilder[T]` and `StandardScalerModel[T]` standardize dense feature columns by removing the per-column mean (`μ`) and dividing by the per-column standard deviation (`σ`):

```text
z = (x - μ) / σ
```

Both centering (`WithMean`) and scaling (`WithStd`) can be toggled independently, and the estimator supports `float32`, `float64`, and named floating-point types (`~float32 | ~float64`).

## Full Standardization (`WithMean(true)` and `WithStd(true)`)

Derived from `TestStandardScalerTransform` in `operations_test.go`:

```go
features, err := sciencekit.NewMatrix(4, 2, []float64{
	0, 0,
	2, 2,
	4, 4,
	6, 6,
})
if err != nil {
	return err
}

builder, err := sciencekit.NewStandardScalerBuilder[float64]()
if err != nil {
	return err
}
defer builder.Close()

if err := builder.WithMean(true); err != nil {
	return err
}
if err := builder.WithStd(true); err != nil {
	return err
}

model, err := builder.Fit(features)
if err != nil {
	return err
}
defer model.Close()

transformed, err := model.Transform(features)
if err != nil {
	return err
}
// transformed.Rows == 4, transformed.Columns == 2
// Each column has mean 0 and unit variance.
```

## Center-Only Transformation (`WithStd(false)`)

When you want to shift columns to zero mean while preserving their original units and variance, disable standard-deviation division with `WithStd(false)` (from `ExampleNewStandardScalerBuilder` in `example_test.go` and `TestStandardScalerTransform` in `operations_test.go`):

```go
features, err := sciencekit.NewMatrix(3, 1, []float64{1, 2, 3})
if err != nil {
	return err
}

builder, err := sciencekit.NewStandardScalerBuilder[float64]()
if err != nil {
	return err
}
defer builder.Close()

if err := builder.WithMean(true); err != nil {
	return err
}
if err := builder.WithStd(false); err != nil {
	return err
}

model, err := builder.Fit(features)
if err != nil {
	return err
}
defer model.Close()

transformed, err := model.Transform(features)
if err != nil {
	return err
}
// transformed.Data == [-1.0, 0.0, 1.0]
```

## Builder Options

| Method | Default in Native Library | Description |
| --- | --- | --- |
| `WithMean(enabled bool) error` | `true` | Subtracts the fitted column mean during `Transform`. |
| `WithStd(enabled bool) error` | `true` | Divides each column by its fitted standard deviation during `Transform`. |
| `Backend(kind BackendKind) error` | `BackendFaer` | Records and dispatches the selected `BackendKind` (`BackendFaer`, `BackendMatrixMultiply`, `BackendNdArrayLinalg`) uniformly with every other `sciencekit` estimator. |

## Output Ownership and Persistence Contract

- **`Transform(features Matrix[T]) (Matrix[T], error)`** never mutates `features.Data` in place. It returns a brand-new `Matrix[T]` with `Rows == features.Rows`, `Columns == features.Columns`, and a freshly allocated Go `[]T` slice.
- **Column mismatch:** Passing a matrix to `Transform` with a different number of columns than the matrix passed to `Fit` fails with `StatusShape`.
- **Persistence status:** `StandardScalerModel[T]` exposes `Save(path string) error` to match the uniform model handle contract, but the underlying `sciencekit_ffi` persistence container currently supports only double-precision linear regression. Calling `scaler.Save(path)` returns a `*ScienceKitError` with `StatusUnsupported` (`IsStatus(err, sciencekit.StatusUnsupported) == true`). See [Model Persistence](persistence.md) for details.
