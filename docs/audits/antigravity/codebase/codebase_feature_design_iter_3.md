# Codebase Feature Design (Iteration 3)

## 1. Test Fixes
### 1.1 `test_features_iter4.cpp`
Update expectation strings to match `SimpleJsonBuilder` output (compact JSON).
- Change `\"depth\": 42` to `\"depth\":42`.
- Change `\"trim\": true` to `\"trim\":true`.

## 2. Code Cleanup
### 2.1 `LogProcessor` Unused Constants
Remove or comment out:
- `VG_LINE_MIN_LEN`
- `MATCH_BYTES_HEAD_LEN`
- `MATCH_BLOCKS_LEN`
- `NUM_START_KEYS`
(Check if they are truly unused. Compiler says so).

### 2.2 `CLI Parser` Style
Rename `MAX_DEPTH` to `maxDepth` (internal constant).
Rename `MAX_MARKER_LENGTH` to `maxMarkerLength`.
Rename `ERROR_MSG_BUFFER_SIZE` to `errorMsgBufferSize`.

### 2.3 `LogWriter` Style
Rename `RED` -> `red`, `GREEN` -> `green`, etc. (Internal constants).

## 3. Backward Compatibility
- Compact JSON in `Options::dump` is a formatting change. Since `Options::dump` is for debugging/config dump, compact vs pretty is minor. We proceed with compact for consistency with `SimpleJsonBuilder`.

## 4. Verification
- Run `test_features_iter4`.
- Run full build to ensure no warnings (if possible).
