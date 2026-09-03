# Hidden recovery safety layer

## Purpose and location

The snapshot is a last-resort guard against an unexpected alternate deletion path or interrupted marked game-over sequence. It is not a save slot and not rollback history.

At runtime the root is derived from `Kingmaker.Utility.ApplicationPaths.persistentDataPath` (falling back to Unity's `Application.persistentDataPath`) and is displayed in UMM:

```text
<Kingmaker persistent data>/LastAzlantiPreserver/Recovery
```

Kingmaker scans only `<Kingmaker persistent data>/Saved Games` (or its beta-only test name), so `snapshot.bin` is never game-visible.

## Snapshot transaction

Before the observed game-over deletion call:

1. The active IronMan path must normalize to one direct `.zks` or `.zip` child of the exact save root and must be a non-reparse-point file.
2. Source length/last-write UTC and SHA-256 are captured.
3. Bytes are copied into a unique mod-owned staging directory; the destination stream is flushed to disk and closed.
4. The copy must be nonempty, equal length, and SHA-256-identical; the source must retain its original length/time across the copy.
5. Metadata is flushed alongside the staged copy.
6. Same-volume directory renames replace the prior identity directory. A fixed hidden `previous` transaction directory permits rollback if the commit move fails, then is removed. No chronological names/history remain.
7. Only after success is `pending.json` written atomically for the current game-over operation.

An identity is SHA-256 of normalized source path plus campaign `GameId`; multiple campaigns can each retain one current snapshot without sharing or accumulating checkpoints. Snapshot code never opens the compressed save as an archive and never deletes/truncates its source.

Metadata records original full path/name, length, source last-write UTC, source/recovery hashes, game ID/name, save name/type, game-over UTC, format, recovery identity, and mod version. Runtime metadata is not committed.

## Restore policy

Automatic restore is evaluated only while completing the exact in-memory game-over context that created the matching operation GUID marker. It requires valid metadata/marker identity, exact original path under the save root, valid snapshot length/hash, and an absent original. Restore copies to a non-save `.tmp` file in the save root, flushes and validates it, then uses `File.Move` to create the original path; this operation fails rather than overwriting if another writer creates the original. The marker is cleared only after success. A restored save list is explicitly refreshed.

The expected path is simpler: deletion is intercepted, the original exists at completion, and the marker is cleared while the current snapshot remains.

After a process interruption, automatic restoration is deliberately not attempted because the disappearance cannot be bounded as tightly after restart. The UMM action is enabled only when a pending marker and validated snapshot exist and the recorded original is absent. The player must tick the explicit confirmation box. If the original exists, the action is disabled and never overwrites it.

Manual load-screen deletion never enters the game-over prefix, never creates a marker, and therefore cannot invoke automatic or guarded resurrection. Stale markers are cleared when their original is observed alive.

## Guarded fallback procedure

Use only a disposable copied save:

1. Open UMM and note the recovery status/path.
2. Verify the recorded original is absent and UMM reports a validated pending recovery.
3. Ensure no live file exists at that exact path.
4. Tick the confirmation checkbox.
5. Press **Restore validated pending recovery**.
6. Return to/reopen the load screen and verify exactly one save appears.

If validation reports metadata/hash/path failure, do not alter the snapshot manually. Preserve the recovery directory for diagnosis and restore the user's independent backup instead.
