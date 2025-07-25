# Advanced Filtering with vglog-filter

## Signature Depth (`-d`/`--depth`)
- The signature depth controls how many lines from each error block are used to generate a unique signature for deduplication.
- Example: `-d 2` uses the first two lines of each block. `-d 0` uses all lines (unlimited depth).
- Lower depth may group more errors together; higher depth distinguishes more unique blocks.

## Marker Customization (`-m`/`--marker`)
- By default, only log entries after the last occurrence of the marker string are processed.
- Use `-m "My Marker"` to set a custom marker string.
- Use `-k` to ignore the marker and process the entire file.

## Deduplication Logic
- Each error block is canonicalized: addresses, line numbers, array indices, and template parameters are replaced with placeholders.
- The canonicalized lines (up to the specified depth) form a signature.
- Only the first occurrence of each unique signature is output; duplicates are omitted.

## Raw vs. Scrubbed Output (`-v`/`--verbose`)
- By default, addresses and certain patterns are scrubbed for readability.
- Use `-v` to disable scrubbing and see the raw log blocks.

## Example: Custom Filtering
```sh
vglog-filter -d 3 -m "==12345== My Custom Marker" mylog.log > filtered.log
```
- This uses a signature depth of 3 and starts processing after the last occurrence of the custom marker. 