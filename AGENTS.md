# Repository instructions

- This repository contains only the standalone **Last Azlanti Preserver** mod.
- Never copy code into another Kingmaker mod or modify an installed mod other than `KingmakerLastAzlantiPreserver`.
- Treat the locally installed Kingmaker 2.1.7b assemblies as the runtime contract source of truth.
- Do not commit game assemblies, saves, logs, runtime recovery data, extracted assets, absolute personal paths, or `GamePath.props`.
- Keep Harmony entrypoints thin. Policy, Kingmaker integration, recovery filesystem work, UI, and logging stay separated.
- Preserve manual deletion and all non-Last-Azlanti behavior. Never add a game-visible save.
- Build with C# 7.3 for .NET Framework 4.7.2 and use the installed Harmony12/UMM assemblies with `Private=False`.
- A build may be compilation-qualified after automated checks. Runtime qualification requires the disposable-campaign procedure in `docs/SMOKE-TEST.md`.
