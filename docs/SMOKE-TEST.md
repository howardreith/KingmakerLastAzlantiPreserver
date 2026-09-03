1. Back up the entire Kingmaker Saved Games directory outside the Owlcat directory.
2. Disable or remove the original FirstAzlanti mod.
3. Use a disposable new campaign.
4. Initially disable Steam Cloud, then test Steam Cloud separately later.
5. Never use the owners real campaign for destructive qualification.

# Human runtime smoke test

Record Kingmaker version, UMM version, mod package SHA-256, enabled mods, test timestamp, and every observed result. Keep saves/logs/screenshots outside Git; do not commit them. A failed step means runtime qualification has not passed.

## Preparation

1. Exit Kingmaker and confirm no `Kingmaker` process remains.
2. Run `scripts/Install.ps1 -WhatIf`; verify it names only `<KINGMAKER_INSTALL>/Mods/KingmakerLastAzlantiPreserver`.
3. Run `scripts/Install.ps1`; verify UMM shows version 0.1.0 and no red status.
4. Open the mod panel. Confirm protection is `AVAILABLE`, both resolved hooks have the documented exact names, preservation/recovery are enabled, and no FirstAzlanti warning appears.
5. Keep the independent full save-directory backup untouched throughout qualification.

## A. Baseline behavior

If the owner elects to run the destructive vanilla control, disable this mod, create a separate disposable Last Azlanti campaign, reach its autosave, trigger protagonist death/party wipe, return to the main menu, and record whether vanilla deletes the save. Destroy no real save. This optional control must never be performed against the owner's campaign.

## B. Core Last Azlanti preservation

1. Enable the mod and create a new disposable campaign with Kingmaker's Last Azlanti / Only One Save option.
2. Reach a legitimate autosave, then wait until saving has completed.
3. Confirm ordinary manual save and quicksave remain unavailable.
4. In `Saved Games`, record the one live filename, byte length, last-write UTC, and `Get-FileHash -Algorithm SHA256` result.
5. Confirm UMM reports that a Last Azlanti save is recognized.
6. Kill the protagonist or trigger a party wipe.
7. Confirm the normal game-over presentation remains visible and there is no automatic reload.
8. Return to the main menu.
9. Confirm the same one save appears and no second save exists.
10. Load it and confirm it resumes at the last legitimate autosave, not a new checkpoint.
11. Repeat death, return-to-menu, and reload at least three times. Record each live filename/count/hash transition and UMM interception/recovery result.

## C. Save discipline

1. Confirm exactly one game-visible save remains for the disposable campaign.
2. Confirm no quicksave/manual-save command or alternate-slot loophole became available.
3. Inspect the UMM-displayed recovery directory and confirm its `snapshot.bin` does not appear in Kingmaker's load screen.
4. Progress to another legitimate autosave and confirm Kingmaker overwrites/updates its one normal slot as before.
5. Confirm no chronological recovery files accumulate: one `snapshot.bin` and one `metadata.json` exist for that source identity, with no retained stage/previous directory.

## D. Manual deletion

1. From the normal load-game UI, deliberately delete a disposable Last Azlanti save.
2. Confirm the UI deletion completes and the save disappears.
3. Restart/refresh the load screen and confirm it is not automatically resurrected.
4. Confirm no pending game-over marker was created and UMM's guarded restore action is disabled.

## E. Non-Last-Azlanti regression

1. Create or load a separate ordinary disposable campaign.
2. Confirm manual saves, quicksaves, autosaves, loading, overwriting, and deletion behave exactly as with the mod disabled.
3. Confirm UMM reports no currently recognized Last Azlanti save for that campaign and no snapshot/marker is created by ordinary deletion.

## F. Restart and recovery

1. In a fresh disposable Last Azlanti campaign, die, return to the main menu, and exit Kingmaker normally.
2. Restart Kingmaker and confirm the preserved save remains available and loadable.
3. For fallback testing, work against a copied disposable save only. Preserve the original elsewhere first.
4. Produce/retain a mod-created pending game-over marker using the documented disposable sequence; never manufacture a marker for a real save.
5. With Kingmaker closed, remove only the copied disposable live file so the recorded path is absent.
6. Restart, open UMM, and confirm the recovery action is enabled only after metadata/hash/path validation.
7. Confirm it does nothing until the explicit confirmation checkbox is selected.
8. Confirm restoration creates only the recorded missing original, never overwrites an existing file, clears the marker, and yields exactly one loadable game-visible save.

## G. Compatibility

1. After isolated testing passes, enable the owner's normal gameplay mods, excluding FirstAzlanti or any duplicate Last Azlanti preservation mod.
2. Repeat one disposable death/reload cycle.
3. Confirm no red UMM status, compatibility warning requiring investigation, or save-system exception appears.
4. Re-enable Steam Cloud separately, create another disposable campaign, repeat at least three death/reload cycles plus a full restart, and record cloud/local filenames and results.
5. Report Steam Cloud as **qualified** only if that separate observed test passes; otherwise report it as failed or unqualified.

## Qualification outcome

Compilation qualification does not imply runtime qualification. Mark version 0.1.0 runtime-qualified only after every required non-optional step above passes with recorded disposable-campaign evidence. Do not publish a GitHub release beforehand.
