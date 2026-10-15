# Hidden recovery safety layer

## Purpose and location

The snapshot is a last-resort guard against an unexpected alternate deletion path or interrupted marked game-over sequence. It is not a save slot, rollback history, or evidence that game-over loading may be enabled.

At runtime the root is derived from `Kingmaker.Utility.ApplicationPaths.persistentDataPath` (falling back to Unity's `Application.persistentDataPath`) and is displayed under **Show troubleshooting** in the UMM panel:

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

## Format compatibility

`metadata.json` and `pending.json` both carry `FormatVersion`. Format 1 is the structure and meaning written since v0.1.0; v0.1.2 still writes and reads exactly that format.

- A recovery is accepted only when both files carry a supported format and the same format. Missing, unknown, or disagreeing format versions fail closed.
- `ModVersion` records which mod release wrote the snapshot. It is provenance only: it must be a well-formed release number (for example `0.1.1`), but which release wrote a supported-format recovery does not decide whether another release may restore it. Since v0.1.2, a valid recovery left pending by 0.1.0 or 0.1.1, or written by a later release that still uses format 1, can be restored. Releases 0.1.0 and 0.1.1 themselves only accept recoveries written by their own exact version.
- Reading and evaluating recovery data never rewrites it. Old snapshots are not migrated.
- Any future change to the recovery file structure or to the meaning of an existing field must introduce a new format version rather than rely on the mod release number to keep older or newer readers away.

Every other check in this document applies regardless of which release wrote the recovery.

## Restore policy

Automatic restore is evaluated only while completing the exact in-memory game-over context that created the matching operation GUID marker. It requires valid metadata/marker identity, exact original path under the save root, valid snapshot length/hash, and an absent original. Restore copies to a non-save `.tmp` file in the save root, flushes and validates it, then uses `File.Move` to create the original path; this operation fails rather than overwriting if another writer creates the original. The marker is cleared only after success. A restored save list is explicitly refreshed.

The expected path is simpler: deletion is intercepted, the original exists at completion, and the marker is cleared while the current snapshot remains. Only this live native source—not the snapshot—can support a v0.1.1 UI outcome. The synchronous recovery/deletion context is closed before any UI-only preserved-operation record is created; that record can neither suppress deletion nor restore bytes.

After a process interruption, automatic restoration is deliberately not attempted because the disappearance cannot be bounded as tightly after restart. The UMM panel shows its **Recovery** section only when the latest pending marker needs attention. The **Restore save** action exists only when a pending marker and validated snapshot exist and the recorded original is absent, and it stays disabled until the player ticks the explicit confirmation box; a confirmation applies only to the recovery it was given for. A pending recovery that fails validation is shown as blocked, with its reason, and offers no restore action. If the original exists, nothing is offered and nothing is overwritten; the state remains visible under **Show troubleshooting**. Opening the panel or expanding troubleshooting only reads the cached status, which is re-evaluated at most once a minute or on an explicit refresh.

Manual load-screen deletion never enters the game-over prefix, never creates a marker, and therefore cannot invoke automatic or guarded resurrection. If deletion occurs from a game-over-opened native load window, it remains destructive and causes live UI eligibility to fail. Stale markers are cleared when their original is observed alive.

## Guarded fallback procedure

Use only a disposable copied save:

1. Open UMM, select **Show troubleshooting**, and note the guarded recovery status and recovery directory.
2. Verify the recorded original is absent and the **Recovery** section reports that a verified backup can restore it.
3. Ensure no live file exists at that exact path.
4. Tick **I confirm: restore this save to its original location**.
5. Press **Restore save**.
6. Return to/reopen the load screen and verify exactly one save appears.

If validation reports metadata/hash/path failure, do not alter the snapshot manually. Preserve the recovery directory for diagnosis and restore the user's independent backup instead.
