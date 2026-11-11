# Quickstart

Once `sciencekit_ffi` is built and linked (see [Installation](installation.md)), you can train models and transform dense matrices in a few lines of Go. Every example below comes straight from `examples/` in the repository and can be run directly with `go run`.

## 1. Ordinary Least Squares (`LinearRegression`)

The end-to-end supervised workflow follows four explicit steps:
1. Wrap a row-major Go slice in a validated `Matrix[T]` via `NewMatrix`.
2. Create a `LinearRegressionBuilder[T]` and `defer builder.Close()`.
3. Call `Fit(features, targets)` to obtain an immutable `LinearRegressionModel[T]` and `defer model.Close()`.
4. Run `Predict(features)` and `Score(features, targets)` (`R²` coefficient of determination).

From `examples/linearregression/main.go` (fitting `y = 1 + 2·x₁ + 3·x₂`):

```go
package main

import (
	"fmt"
	"log"

	sciencekit "github.com/neurono-ml/sciencekit-go"
)

func main() {
	features, err := sciencekit.NewMatrix(4, 2, []float64{
		0, 0,
		1, 0,
		0, 1,
		2, 3,
	})
	if err != nil {
		log.Fatal(err)
	}
	builder, err := sciencekit.NewLinearRegressionBuilder[float64]()
	if err != nil {
		log.Fatal(err)
	}
	defer builder.Close()

	model, err := builder.Fit(features, []float64{1, 3, 4, 14})
	if err != nil {
		log.Fatal(err)
	}
	defer model.Close()

	predictions, err := model.Predict(features)
	if err != nil {
		log.Fatal(err)
	}
	score, err := model.Score(features, []float64{1, 3, 4, 14})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("predictions: %.4f\nR²: %.4f\n", predictions, score)
}
```

Run it from the repository root:

```sh
go run ./examples/linearregression
```

Expected output:

```text
predictions: [1.0000 3.0000 4.0000 14.0000]
R²: 1.0000
```

---

## 2. Feature Standardization (`StandardScaler`)

`StandardScalerBuilder[T]` computes per-column mean and standard deviation during `Fit` and returns a standardized `Matrix[T]` on `Transform`.

From `examples/standardscaler/main.go`:

```go
package main

import (
	"fmt"
	"log"

	sciencekit "github.com/neurono-ml/sciencekit-go"
)

func main() {
	features, err := sciencekit.NewMatrix(4, 2, []float64{
		0, 0,
		2, 2,
		4, 4,
		6, 6,
	})
	if err != nil {
		log.Fatal(err)
	}
	builder, err := sciencekit.NewStandardScalerBuilder[float64]()
	if err != nil {
		log.Fatal(err)
	}
	defer builder.Close()

	model, err := builder.Fit(features)
	if err != nil {
		log.Fatal(err)
	}
	defer model.Close()

	transformed, err := model.Transform(features)
	if err != nil {
		log.Fatal(err)
	}
	for row := 0; row < transformed.Rows; row++ {
		offset := row * transformed.Columns
		fmt.Printf("%.4f\n", transformed.Data[offset:offset+transformed.Columns])
	}
}
```

Run it from the repository root:

```sh
go run ./examples/standardscaler
```

Expected output:

```text
[-1.3416 -1.3416]
[-0.4472 -0.4472]
[0.4472 0.4472]
[1.3416 1.3416]
```

---

## What Happens Under the Hood

<div class="sk-box sk-box--tip">
  <strong>Zero slice aliasing across FFI:</strong>
  <ul>
    <li><code>NewMatrix(rows, columns, data)</code> borrows <code>data</code> without copying in Go and checks <code>rows &gt; 0</code>, <code>columns &gt; 0</code>, and <code>len(data) == rows*columns</code>.</li>
    <li>When <code>Fit</code>, <code>Predict</code>, <code>Score</code>, or <code>Transform</code> runs, the binding copies the slice into temporary C-heap memory, calls <code>sciencekit_ffi</code>, copies output buffers into fresh Go slices, and releases all native buffers before returning.</li>
    <li>Calling <code>defer builder.Close()</code> and <code>defer model.Close()</code> releases the underlying opaque Rust handles deterministically; a <code>runtime.SetFinalizer</code> backs up each handle if forgotten.</li>
  </ul>
</div>

## Next Steps

- Configure intercepts, single precision (`float32`), and backends in **[Linear Regression](guides/linear-regression.md)**.
- Control centering and scaling independently in **[Standard Scaler](guides/standard-scaler.md)**.
- Persist and reload fitted models with **[Model Persistence](guides/persistence.md)**.
- Inspect error statuses with `IsStatus` in **[Errors and Status Codes](guides/errors.md)**.
