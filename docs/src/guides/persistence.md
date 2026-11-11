# Model Persistence

`sciencekit-go` persists and reloads fitted models through the native `sciencekit` interop state container (`sk_ffi_model_save` and `sk_ffi_model_load`). Models saved in Go use the exact same binary/state representation as models saved from Rust or any other `sciencekit_ffi` language binding.

## Round-Trip Example (`Save` and `LoadLinearRegression`)

Derived from `TestPersistenceRoundTrip` in `persistence_test.go`:

```go
package main

import (
	"fmt"
	"log"
	"path/filepath"

	sciencekit "github.com/neurono-ml/sciencekit-go"
)

func saveAndReload(directory string) error {
	features, err := sciencekit.NewMatrix(4, 2, []float64{
		0, 0,
		1, 0,
		0, 1,
		2, 3,
	})
	if err != nil {
		return err
	}
	targets := []float64{1, 3, 4, 14}
	path := filepath.Join(directory, "linear-regression.skstate")

	builder, err := sciencekit.NewLinearRegressionBuilder[float64]()
	if err != nil {
		return err
	}
	defer builder.Close()

	model, err := builder.Fit(features, targets)
	if err != nil {
		return err
	}
	defer model.Close()

	if err := model.Save(path); err != nil {
		return err
	}

	loaded, err := sciencekit.LoadLinearRegression(path)
	if err != nil {
		return err
	}
	defer loaded.Close()

	query, err := sciencekit.NewMatrix(1, 2, []float64{2, 3})
	if err != nil {
		return err
	}
	predictions, err := loaded.Predict(query)
	if err != nil {
		return err
	}
	fmt.Printf("reloaded prediction: %.4f\n", predictions[0]) // 14.0000
	return nil
}

func main() {
	if err := saveAndReload("/tmp"); err != nil {
		log.Fatal(err)
	}
}
```

## Supported Persistence Matrix

Check runtime persistence availability with `sciencekit.HasFeature(sciencekit.FeatureModelPersistence)`. At the current C ABI revision (`v1`), persistence support covers double-precision linear regression:

| Model Type | `Save(path)` | Loader Function | Status |
| --- | --- | --- | --- |
| `LinearRegressionModel[float64]` | Supported | `LoadLinearRegression(path)` | <span class="sk-pill sk-pill--emerald">Supported</span> |
| `LinearRegressionModel[float32]` | Returns `StatusUnsupported` | — | <span class="sk-pill sk-pill--amber">Unsupported in ABI v1</span> |
| `StandardScalerModel[float64]` | Returns `StatusUnsupported` | — | <span class="sk-pill sk-pill--amber">Unsupported in ABI v1</span> |
| `StandardScalerModel[float32]` | Returns `StatusUnsupported` | — | <span class="sk-pill sk-pill--amber">Unsupported in ABI v1</span> |

## Error Handling for Persistence Operations

Derived from `TestSaveRejectsUnsupportedModels`, `TestLoadMissingFile` (`persistence_test.go`), and `TestEmptyPathsAreRejected` (`errors_test.go`):

```go
// 1. Empty paths are rejected in Go before calling C:
if _, err := sciencekit.LoadLinearRegression(""); sciencekit.IsStatus(err, sciencekit.StatusInvalidArgument) {
	// Operation == "load", Message == "the path is empty"
}

// 2. Unsupported model families or precisions return StatusUnsupported:
if err := scaler.Save(path); sciencekit.IsStatus(err, sciencekit.StatusUnsupported) {
	// Native ABI explicitly reports that scaler persistence is unsupported
}

// 3. Missing or unreadable files return StatusIO (or StatusUnknown with native message):
loaded, err := sciencekit.LoadLinearRegression("/nonexistent/absent.skstate")
if err != nil {
	// loaded is guaranteed nil; err carries the native filesystem message
}
```

## How `LoadLinearRegression` Respects `cgocheck2`

In `native_model.go`, `sk_ffi_model_load(path, out_model)` writes a `*C.SKFfiModel` pointer into an output pointer slot. Because Go's cgo pointer rules forbid C code from writing a C pointer into Go-managed stack or heap memory across a cgo call, `loadNativeModel` allocates the output pointer slot itself via `C.malloc`, reads `*slot` back into Go after `sk_ffi_model_load` returns, and frees the slot immediately with `defer C.free(...)`. Every loaded model is also registered with `runtime.SetFinalizer` so its handle obeys the exact same lifecycle guarantees as a freshly fitted model.
