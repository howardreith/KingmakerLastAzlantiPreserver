# UMM 0.31.1 baseline evidence

Machine-generated outputs exported 2026-11-24 21:13 UTC for candidate commit `c39b471eaad5b853e793c1594c8845def74a3680`. Each row names what produced that output (its
source commit, or the reused input it describes); outputs produced at another commit are identified there.
Only local path prefixes were replaced: `<repo>` (this checkout or its temporary clone root), `<temp>`, `<game>`
(the Kingmaker installation, read-only), `<buildtools>`, `<reference-assemblies>`, `<dotnet>`, `<controller>` (the agent-review controller), `<dev>` (the owner's development folder), `<steam>`, `<user-profile>`, `<fleet>` (the owner's fleet mission folder,
outside this repository). Line endings were normalized to LF and a UTF-8 byte-order mark was dropped; nothing else was
edited. Raw SHA-256 is of the original output bytes. Exported SHA-256 is of the committed Git blob of each file in this
folder (LF bytes; a Windows checkout with `core.autocrlf` may show CRLF in the working tree, so hash the blob, not the
checked-out file). To verify one, from the repository root (Git Bash or any POSIX shell with sha256sum; the second
command, with Python, works in Windows PowerShell and cmd.exe):

```
git cat-file blob HEAD:docs/evidence/umm-0311/<file> | sha256sum
python -c "import hashlib,subprocess,sys; print(hashlib.sha256(subprocess.check_output(['git','cat-file','blob','HEAD:docs/evidence/umm-0311/'+sys.argv[1]])).hexdigest())" <file>
```

| File | Produced by | Raw SHA-256 | Exported SHA-256 (Git blob) |
| --- | --- | --- | --- |
| `qualification-summary.json` | 4b4b3ec (Qualify.ps1 -Build -Test -VerifyContracts -Package, clean tree; tooling 27c0af5; product unchanged since) | `80e69515c8299b8f20320824f8d4a43ab305687a74bff6934bb3ab1d740f86e8` (original output, from its first export) | `54051071a6c5ab283b8bb1e59fe5058e1c91762462dfc6b5efd95d74b6a272d2` |
| `build.json` | 4b4b3ec (same qualify run) | `614ba45408f687645c5a5bcbc3dc790b8cf0c2e2d676bcd68b32c60f38b7a716` (original output, from its first export) | `412e71a8e71d646bc30ecb30176088bab07ee096d54158be38859f033074c66e` |
| `tests.json` | 4b4b3ec (same qualify run) | `cd6ce0a776c3bb2c6709beca6ddc84ed72b7a78121b68a8c5248de80d5a5f473` (original output, from its first export) | `a67d472b9f0fe75ee933e3c185a753ed4d145e9a63cca60a7426a0102515596e` |
| `contracts.json` | 4b4b3ec (same qualify run) | `91a1c188221990bfac5f328f1eb5eb47492b17cefe117710de65b0efcf43015a` (original output, from its first export) | `ac543e501218f0716bb7789fdc6a3a61821d12292aac8b5633f5e8fcbf261ed6` |
| `game-over-load-contracts.json` | 4b4b3ec (same qualify run) | `1a65419065d48407c2de62e682f592cab16384fdf542596cee38046cd3b00285` (original output, from its first export) | `e45a749abcf9cb0480389f37ad59d5eaa2c6dd7a0ee3da7cb2fdad6f524fe4c1` |
| `package.json` | 4b4b3ec (same qualify run) | `56724c1ed82bd9c352e86cbb5aec849e5a142b231fc4dfc92022b4f254eae945` (original output, from its first export) | `3c757835fa85fd61494851badd686d337c610a48cc14dc4509bb0e7c0c53030c` |
| `package-validation.json` | 4b4b3ec (same qualify run) | `5bfb8c6eb10797ae2cd64eb73089ca56087cb251bf5d755dc7d4d5775ee4fc85` (original output, from its first export) | `29706049d26aa267cb9642d9a8c5d7957fcba6007adf68d82f5cd846e772f2b5` |
| `loader-baseline.json` | c39b471 (temporary clone; 157/157) | `15538a3542350d383cc8493afda1773d02ddcb90d00d3a5736dc4b27f2a6112b` | `d2608aba534d5e0c7ac929631de3d37591825146f1c594c2ef9477d82e2121d6` |
| `r1f1-reproduction.txt` | focused reproduction on temporary clones of d16445d and 6352498 | `7a869b1113a58f86adae6d6c8febd3ad606fff3aa0dcd3bc18e443cadf0fee54` | `300789c5fc6681bbcf39c39122e4718e57210ea140d24335019052d0de1c07a5` |
| `docs-link-check.json` | `4b4b3ec` | `64b18869dfa5adf15f474c7653288cbe5a513869b0f7805deaf314703a843848` (original output, from its first export) | `4846d9427e30426d3a208698e72154d2d77688d6567670604f8afbf0cff11487` |
| `loader-profiles-managed.json` | reused managed loader-profile results for the unchanged DLL fadf2dab | `4c7fab048afa6350dd5b439d2208c00250cc56ec81bf2cf9ca465fb9220b0af9` (original output, from its first export) | `a84539352817f11bc11f49c9539f1027c5bd0a970e857d2531085d70cff51737` |
| `api-audit.json` | reused static audit of the unchanged DLL fadf2dab | `106fde3968a78d951116982c7911f68d468c85c16362b58d6a07412d20f32f41` (original output, from its first export) | `66ef3435dfcf708929a4602d00a909f989961761e3f80037330c775216e9f5be` |
| `loader-profile-inventory.json` | reused profile inventory with the unchanged DLL fadf2dab | `d52858bd0ff11436d831e8d0876a242279cb071d6708d73474242feaa38b3456` (original output, from its first export) | `9a839002d38f6dd0fa5907826e437435e05630cb55c4cf4e5e1c3f076db02dd8` |
| `newest-stable-selection.json` | reused fleet record measured 2026-11-23 | `3b3afcb904f00b33006d74c481fbce4bf6e4992e7f9001d28cdf28d589f9f56f` (original output, from its first export) | `150806fc23701c046ae9980c73c91d12c3badb671d7e30c126b61060784dd51e` |
| `loader-profiles.md` | fleet loader-profile record (reused) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` (original output, from its first export) | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | audit tool source (reused) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` (original output, from its first export) | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | audit tool project (reused) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` (original output, from its first export) | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
