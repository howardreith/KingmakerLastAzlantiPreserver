# UMM 0.31.1 baseline evidence

Machine-generated outputs for candidate commit `363c484d538612597c76839a49d82aea3e446b83`, exported 2026-11-24 00:49 UTC.
Only local path prefixes were replaced: `<repo>` (this checkout or its temporary clone root), `<temp>`, `<game>`
(the Kingmaker installation, read-only), `<buildtools>`, `<reference-assemblies>`, `<dotnet>`, `<user-profile>`, `<fleet>` (the owner's fleet mission folder,
outside this repository). Line endings were normalized to LF and a UTF-8 byte-order mark was dropped; nothing else was
edited. Raw SHA-256 is of the original output bytes. Exported SHA-256 is of the committed Git blob of each file in this
folder (LF bytes; a Windows checkout with `core.autocrlf` may show CRLF in the working tree, so hash the blob, not the
checked-out file). To verify one, from the repository root:

```
git cat-file blob HEAD:docs/evidence/umm-0311/<file> | sha256sum
python -c "import hashlib,subprocess,sys; print(hashlib.sha256(subprocess.check_output(['git','cat-file','blob','HEAD:docs/evidence/umm-0311/'+sys.argv[1]])).hexdigest())" <file>
```

| File | Raw SHA-256 | Exported SHA-256 (Git blob) |
| --- | --- | --- |
| `qualification-summary.json` | `d45f8774be3532d5502249e5e9d73aa0d011189ba20cdc9d9f99af3633655502` | `6ac61ba21f857d1588994e9e654abddfdbbd5f7eb074cfff2aba2b991db233ee` |
| `build.json` | `fc050e53445f66c000a6330519342e02ada1fae6cc42f48b526f86498183ae01` | `2467f4c664b66acf8691d8209e3b7a5899a67ab54f70ecd5ccef66049702f846` |
| `tests.json` | `70fc947ae9c3d0000ef4619bf36316b3e93a838d5e22dbc9f1a679ff24bb929c` | `6d1b4bd12d9a7137fdd939d127e57f509fffec9d0e30939d794499c2fd32fbf9` |
| `contracts.json` | `bdc0819800054481c32dab6d616ebdc8fb3030c6ced7fc31e7a818ce637c3fc8` | `c3f9c9a3441f73caa272067657b857b17b073d6936748a08d83945b55a578512` |
| `game-over-load-contracts.json` | `e6e57439d4c0442a05a3e3fc0f3ad9a9047e0e1d15dd9df9870407dc5540a183` | `d1842222beaf419373397d4db50938e96b5dd6e96e2a5c5f95093d75cf8c0c1c` |
| `package.json` | `b321bf6a19914940b44d430f2e02fbdc00951ac121d897c0001e615d8f8b6251` | `d16bbf1f00af630cb9b687c3674f79627846d424ff021a924b54963da48e4def` |
| `package-validation.json` | `1fc2e5d529e9db041ae5ea689c6c87d95f9623d39b7b2a73555179f7aa9bfeba` | `5adeac007c053c61807098c9a03a62e3490292732e4e9236febd8b0986cc7300` |
| `loader-baseline.json` | `f9f5dbaba99fe03ba9309f5a772eb367f81cb50de72fa4a2c5256804c3de6136` | `aba00dc9a4b4d0bb768df1c4cd96da8b3fab79db2d0f68c278121b8b8e5fc712` |
| `loader-profiles-managed.json` | `4c7fab048afa6350dd5b439d2208c00250cc56ec81bf2cf9ca465fb9220b0af9` | `a84539352817f11bc11f49c9539f1027c5bd0a970e857d2531085d70cff51737` |
| `api-audit.json` | `106fde3968a78d951116982c7911f68d468c85c16362b58d6a07412d20f32f41` | `66ef3435dfcf708929a4602d00a909f989961761e3f80037330c775216e9f5be` |
| `loader-profile-inventory.json` | `53cfa07b7acbda45c798323ad3321aedf9bb0071b6191558cba9de58f22f326f` | `e4160fdd17387eecd887b53653a19e3cb12df85df41b9eaa305bef7ca3c92e0a` |
| `docs-link-check.json` | `056a39bb2afa80f2a3f85f6a344bf6de853c5b16e3473f10abbf0df1a3ea17b8` | `d1c289efe3e0016494b0c99c890f7cafae48919daae7e425ba056e5b2bed0963` |
| `newest-stable-selection.json` | `3b3afcb904f00b33006d74c481fbce4bf6e4992e7f9001d28cdf28d589f9f56f` | `150806fc23701c046ae9980c73c91d12c3badb671d7e30c126b61060784dd51e` |
| `loader-profiles.md` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
