# UMM 0.31.1 baseline evidence

Machine-generated outputs for candidate commit `5d00290c9027e6cb49c46b0414eb512ae099615e`, exported 2026-11-24 01:22 UTC.
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

| File | Raw SHA-256 | Exported SHA-256 (Git blob) |
| --- | --- | --- |
| `qualification-summary.json` | `5bd0413f5a36db189631abd27ff0f78c60a3679e65a774af85862a9578092337` | `262e25401516825875690059bc7c00353570953df05eee2d88518b6829d5e60c` |
| `build.json` | `6766e53d26ef7854ba00f37fda4e878b5847b9db4b1d658cd3e4c449eac0b1d6` | `38815721083aedd40dd0e2bdf04cff9e300e3d95927b26f33119e1e952fd254b` |
| `tests.json` | `7c542bb7ed2a09fa2533eb831e4a7cfe109f06103aa66e28eedd40958bb13dab` | `1af92254e142924fac8ef72b33beeffba1cfa8149436ed4cc5724c7c4734194a` |
| `contracts.json` | `b870ba28c0f662681237c371e5fc7ff33b062d3b78ba4895a3dfefb72a2c21c9` | `b0896f2f6c8b29aa993dc57301142546acc02fb147a2b89e11f2c8ce0d292700` |
| `game-over-load-contracts.json` | `e7c7f36f70b6f3913dc18233d9003dccb579cbc386500491b095bb6ea180e980` | `ac25cbf2649751bc2f9b9067ab0b980e1bd628cc83625f17fafeb2cb0b2272d1` |
| `package.json` | `1b8259cf9d1f1691d2d3166f608ff32c2f3adcff47755ce9496802c8b82f767f` | `b09a62a9ac6cb276cc9d740090d435b961f610c3e8a5371576b53393c9cdccd0` |
| `package-validation.json` | `8ce759df02cc23b22061fb2c3df837847bd239538555db70c3f78dbf9cfd58dd` | `79ca2cc9e9a1889b645b9d2c2c5958dc0514a1fce4fc8c7e73491aa420af3bdb` |
| `loader-baseline.json` | `7c35b8f6cf0b8f7ff9c7cb2ed07ae04c1312b447f665b5581c35ceb963ad1d98` | `167ea36050eaf351613fe4f4fa526ffca2d5852693c8697803daa98ad3ba2f93` |
| `loader-profiles-managed.json` | `4c7fab048afa6350dd5b439d2208c00250cc56ec81bf2cf9ca465fb9220b0af9` | `a84539352817f11bc11f49c9539f1027c5bd0a970e857d2531085d70cff51737` |
| `api-audit.json` | `106fde3968a78d951116982c7911f68d468c85c16362b58d6a07412d20f32f41` | `66ef3435dfcf708929a4602d00a909f989961761e3f80037330c775216e9f5be` |
| `loader-profile-inventory.json` | `d52858bd0ff11436d831e8d0876a242279cb071d6708d73474242feaa38b3456` | `9a839002d38f6dd0fa5907826e437435e05630cb55c4cf4e5e1c3f076db02dd8` |
| `docs-link-check.json` | `056a39bb2afa80f2a3f85f6a344bf6de853c5b16e3473f10abbf0df1a3ea17b8` | `d1c289efe3e0016494b0c99c890f7cafae48919daae7e425ba056e5b2bed0963` |
| `newest-stable-selection.json` | `3b3afcb904f00b33006d74c481fbce4bf6e4992e7f9001d28cdf28d589f9f56f` | `150806fc23701c046ae9980c73c91d12c3badb671d7e30c126b61060784dd51e` |
| `loader-profiles.md` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` | `3b2883677f537286a0d6f210327fae8ac8734b40ec7cc5850e92819eaeb03d5e` |
| `loader-api-audit-Program.cs.txt` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` | `be870827024fd41f63235ebb522c489e8d49c7991de7091ad0e14a1a0e935ea3` |
| `loader-api-audit-csproj.txt` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` | `93989652d8252ff54a60ec92c13c1fc41bf94bfa3cf6c9f7f13c877bac761909` |
