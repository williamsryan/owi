# Owi Modifications for Proteus Evaluation

## Build Status

✅ **Successfully built from source** (commit: main branch as of 2026-01-02)

## Build Notes

- Built with OCaml 5.2.0 (upstream targets < 5.2, but core functionality works)
- C library compilation failed (requires wasm32 clang target), but not needed for our use case
- Core symbolic execution engine works perfectly

## Modifications

None yet - using upstream version as-is.

## Known Issues

1. **C library compilation fails** - Missing wasm32 target for clang
   - Impact: Cannot use `owi c` command directly
   - Workaround: Use `owi sym` on pre-compiled WASM files
   - Not a blocker for our evaluation

## Usage for Proteus Evaluation

We use Owi's symbolic execution engine to detect vulnerabilities in WASM binaries.

### Compilation Requirements

**CRITICAL:** WASM binaries must be compiled with specific flags to work with Owi:

```bash
emcc -O0 program.c -o program.wasm \
  -nostartfiles \
  -Wl,--no-entry \
  -Wl,--export-all \
  -s ERROR_ON_UNDEFINED_SYMBOLS=0 \
  -s ALLOW_MEMORY_GROWTH=1
```

**Key flags explained:**
- `-nostartfiles` + `-Wl,--no-entry`: No entry point required (library mode)
- `-Wl,--export-all`: Export ALL functions and prevent dead code elimination
- This allows Owi to analyze any function via `--entry-point=<function_name>`

**Why this matters:**
- Without `--export-all`, optimizer eliminates "unused" functions
- Without `--no-entry`, WASM requires a start function
- Owi needs exported functions to use as entry points for symbolic execution

### Running Owi

```bash
dune exec -- owi sym <file.wasm> --entry-point=<function> --invoke-with-symbols
```

### Output Format

Owi reports vulnerabilities as:
- `[ERROR] Trap: <type>` - Runtime error detected (divide by zero, memory access, etc.)
- `[ERROR] Assert failure` - Assertion violated
- `model { ... }` - Counterexample showing input values that trigger the bug
- `All OK!` - No vulnerabilities found

**Example:**
```
owi: [ERROR] Trap: integer divide by zero
model {
  symbol symbol_0 i32 2
}
owi: [ERROR] Reached problem!
```

### Integration with Proteus

- **Verdict mapping:** ERROR → VULNERABLE, "All OK" → SAFE
- **Confidence:** 0.95 for traps, 0.90 for assertions, 0.80 for safe
- **Metadata:** Extracts trap type and counterexample model
- **Ground truth:** Compare verdicts to Juliet CWE metadata (TP/FP/TN/FN)

## Future Contributions

Potential contributions back to Owi:
- [ ] Fix OCaml 5.2 compatibility
- [ ] Improve WASM binary analysis (if needed)
- [ ] Add JSON output format for easier parsing
- [ ] Performance optimizations for batch analysis
