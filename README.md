# Random Suite

Monorepo for the Random project family.

## Structure

```
├── random-desktop/   Flutter Windows app — desktop random tool
├── random-floating/  .NET 8 WPF app — floating random tool
└── .github/
    ├── workflows/
    │   └── build.yml        CI/CD pipeline
    └── installer/
        ├── installer.iss    Inno Setup script
        └── publish.ps1      One-click local build & package
```

## Build

### CI

Push to `main` triggers three jobs:
- **build-desktop** — Flutter Windows build
- **build-floating** — .NET 8 publish
- **build-installer** — Inno Setup packages both into a single installer

### Local (one-click)

```powershell
.\github\installer\publish.ps1
```

Requires: Flutter SDK, .NET 8 SDK, Inno Setup 6.

## Releases

Download the latest installer from [Releases](https://github.com/mimai114514/random-suite/releases).
