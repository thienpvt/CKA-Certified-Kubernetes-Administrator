# Plan 12-02 — Summary

**Status:** Complete
**Date:** 2026-05-17

## File Modified

- `cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml`

## Trap Entries Dropped

- `pvc-accessmode-rwx-on-rwo-sc`
- `hostpath-pv-without-nodeaffinity`

## Trap Entry Kept

- `pvc-wrong-storageclass` (matches the sole `cka_sim::grade::record_trap` call in `grade.sh:36`)

## Lint Result After Trim

`storage/02-storageclass-dynamic: trap coverage OK` — orphan err lines for the two dropped ids are gone. Overall orphan count dropped from 35 to 33.

## Catalog Untouched

`cka-sim/traps/catalog.yaml` entries for both dropped ids remain (used by other questions and shared taxonomy). Verified with grep.

## No Other Files Touched

`git diff --name-only` lists only `cka-sim/packs/storage/02-storageclass-dynamic/metadata.yaml`.
