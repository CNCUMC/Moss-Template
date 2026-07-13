# Moss-Template

A [dotnet new](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-new) template for developing `Casualties Unknown` mods.

Based on [05126619z/ScavTemplate](https://github.com/05126619z/ScavTemplate).

---

## Quick Start

### Method 1: Using `NewMod.ps1` (Recommended)

1. Download this repository:
   - **Option A**: Click `Code` in the top-right corner of GitHub → `Download ZIP`, extract locally
   - **Option B**: Clone this repository:

```powershell
git clone https://github.com/CNCUMC/Moss-Template.git
cd Moss-Template
```

2. Run the creation script in any directory:

```powershell
cd E:/Projects  # Directory where you want to create the project
<path-to>\NewMod.ps1
```

The script will automatically:
- Auto-install the template (no need to manually run `dotnet new install`)
- Search for Casualties Unknown game directory in Steam installation paths
- Interactively prompt for mod name, GUID, version, etc.
- Call `dotnet new mosstemplate` to generate the project
- All file names and content automatically replaced

3. Build and test:

```powershell
cd MyCoolMod
dotnet build
```

### Method 2: Using `dotnet new` command

After registering the template (see step 1 above), use the command line directly:

```powershell
dotnet new mosstemplate -n MyCoolMod `
    --ModDisplayName "My Cool Mod" `
    --ModGuid "com.example.mycoolmod" `
    --ModVersion "1.0.0" `
    --AuthorName "Your Name" `
    --GameRootPath "E:/SteamLibrary/steamapps/common/Casualties Unknown Demo" `
    --Language "en-US"
```

### Method 3: Clone from GitHub (Traditional)

1. Click [Use this template](https://github.com/new?template_name=Moss-Template) on GitHub to create a repository
2. After cloning, manually replace `MossTemplate` in file names and content
3. Refer to the manual configuration steps below

---

## Template Parameters

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `-n` / `--name` | Project name (PascalCase, e.g. `MyCoolMod`) | Required |
| `--ModDisplayName` | Mod display name (e.g. `My Cool Mod`) | Auto-generated from name |
| `--ModGuid` | Unique mod GUID (format: `yourname.modname`) | `com.example.mymod` |
| `--ModVersion` | Initial version number | `1.0.0` |
| `--AuthorName` | Author name (for LICENSE) | `Your Name` |
| `--GameRootPath` | Game root directory path | Steam default path |
| `--Language` | Language for generated files (`zh-CN` or `en-US`) | `en-US` |

The template automatically replaces:
- `MossTemplate.csproj` → `{ProjectName}.csproj`
- `namespace MossTemplate` → `namespace {ProjectName}`
- `org.explosivehydra.mosstemplate` → `{ModGuid}`
- `Moss Template` → `{ModDisplayName}`
- Version number, LICENSE author name, game DLL paths in csproj

---

## Multi-Language Support

The template supports both Chinese and English, controlled via the `--Language` parameter:

```powershell
# Chinese project (script interface and generated files in Chinese)
.\NewMod.ps1 -Language zh-CN

# English project (script interface and generated files in English)
.\NewMod.ps1 -Language en-US
```

**NewMod.ps1 interface language**: Title, prompts, config summary, completion messages.

**Generated file language**:
- `README.md` / `CHANGELOG.md`: Chinese or English version
- `StartGame.ps1` / `Release.ps1`: Chinese or English interface

---

## About StartGame.ps1

[StartGame.ps1](StartGame.ps1) copies the compiled DLL file to the BepInEx plugin directory in the game directory and automatically launches the game.

**Parameters:**
- `$GamePath` — Game installation directory (e.g. `E:/SteamLibrary/steamapps/common/Casualties Unknown Demo`)
- `$ModNamespace` — Mod namespace (e.g. `MyCoolMod`)

**Command line usage:**

```powershell
.\StartGame.ps1 -GamePath "E:/SteamLibrary/steamapps/common/Casualties Unknown Demo" -ModNamespace "MyCoolMod"
```

### JetBrains Rider Configuration

1. Right-click [StartGame.ps1](StartGame.ps1) → `Run 'StartGame.ps1'`
2. Click the `StartGame.ps1` button next to the build button in the top-right corner → `Edit Configurations...`
3. Fill in `Script arguments:` with: `"E:/SteamLibrary/steamapps/common/Casualties Unknown Demo" "MyCoolMod"`
4. Set `Command parameters` to: `-ExecutionPolicy Bypass`
5. Click the plus next to `Before launch` → `Build Solution` → OK

After that, each time you press the green triangle button next to the build button, the mod's DLL will be automatically copied to the BepInEx plugin directory and the game will start.

### Visual Studio

Right-click [StartGame.ps1](StartGame.ps1) and select `Run`, then manually fill in the parameters. Figure out the specific configuration yourself. :P

---

## Publishing Mods (Release.ps1)

[Release.ps1](Release.ps1) is used to build, package, and publish mods to NexusMods and GitHub Release.

**Basic usage:**

```powershell
.\Release.ps1                          # Interactive version confirmation then publish
.\Release.ps1 -SkipNexus               # Publish to GitHub only
.\Release.ps1 -SkipBuild -SkipGitHub   # Publish to NexusMods only (skip build)
```

**Parameters:**

| Parameter | Description | Default Value |
|-----------|-------------|---------------|
| `-ModNamespace` | Mod namespace (auto-filled) | Required |
| `-ModDisplayName` | Mod display name (auto-filled) | Required |
| `-ModVersion` | Version number (auto-filled, interactive modification) | Required |
| `-NexusModId` | Mod ID on NexusMods | `0` (must specify) |
| `-NexusApiKey` | NexusMods API Key | `$env:NEXUS_API_KEY` |
| `-Configuration` | Build configuration | `Release` |
| `-SkipBuild` | Skip build step | `$false` |
| `-SkipNexus` | Skip NexusMods upload | `$false` |
| `-SkipGitHub` | Skip GitHub Release | `$false` |
| `-ReleaseNotes` | GitHub Release notes | Auto-read from CHANGELOG.md |
| `-Prerelease` | Mark as pre-release | `$false` |

### NexusMods API Key Setup

1. Log in to [NexusMods](https://www.nexusmods.com/)
2. Go to [API Access](https://www.nexusmods.com/casualtiesunknown/users/myaccount?tab=api) page
3. Click `REQUEST API KEY` to get your Key

**Usage:**

```powershell
# Environment variable (recommended, set once and persists)
$env:NEXUS_API_KEY = "your-api-key"
.\Release.ps1

# Or command line parameter
.\Release.ps1 -NexusApiKey "your-api-key"
```

### GitHub Authentication

```powershell
# Install GitHub CLI
winget install GitHub.cli

# Log in
gh auth login
```

### Auto-Read Changelog

If `-ReleaseNotes` is not specified, the script automatically extracts the current version's content from `CHANGELOG.md`:

```markdown
## v1.2.0
- Added xxx feature
- Fixed yyy issue
```

Extracts content between `## v{version}` and the next `## v`.

---

## csproj Reference

The template includes 15 core game DLL references. All paths are managed through MSBuild properties in `Directory.Build.props`:

| Property | Description | Example |
|----------|-------------|---------|
| `$(GameDir)` | Game root directory | `F:/SteamLibrary/steamapps/common/Casualties Unknown Demo` |
| `$(ManagedDir)` | Managed directory | `$(GameDir)/CasualtiesUnknown_Data/Managed` |
| `$(CUCoreLibDll)` | CUCoreLib path (optional) | `$(GameDir)/BepInEx/plugins/CUCoreLib.dll` |

To add additional references (e.g. animation, audio, particles), uncomment or add new entries in csproj:

```xml
<!-- Example: Add audio module -->
<Reference Include="UnityEngine.AudioModule">
    <HintPath>$(ManagedDir)/UnityEngine.AudioModule.dll</HintPath>
</reference>
```

> **Note:** On first use, copy `Directory.Build.props.example` to `Directory.Build.props` and fill in your game path.

---

## License Selection

Choose a license type when creating a project:

| Option | License | Description |
|--------|---------|-------------|
| 1 | MIT | Permissive, recommended for most cases |
| 2 | GPL v3 | Requires derivative works to be open source |
| 3 | LGPL v3 | Allows closed-source use, modifications must be open |

---

## Project Structure

```
Moss-Template/
├── .template.config/
│   └── template.json          # Template configuration (parameter definitions, conditional sources)
├── Directory.Build.props.example  # Game path configuration template
├── MossTemplate.csproj        # Project file
├── Plugin.cs                  # BepInEx plugin entry
├── StartGame.ps1              # Game launch script (English)
├── Release.ps1                # Mod publishing script (English)
├── NewMod.ps1                 # Interactive mod creation script
├── README.md                  # English documentation
├── README_ZH.md               # Chinese documentation
├── CHANGELOG.md               # English changelog template
├── CHANGELOG_ZH.md            # Chinese changelog template
└── LICENSE.md                 # License file
```

Generated project structure:

```
MyCoolMod/
├── Directory.Build.props      # Game path configuration (needs editing)
├── MyCoolMod.csproj           # Project file
├── Plugin.cs                  # Plugin entry
├── StartGame.ps1              # Game launch script
├── Release.ps1                # Mod publishing script
├── README.md                  # Documentation
├── CHANGELOG.md               # Changelog
├── LICENSE.md                 # License
└── .run/
    └── StartGame.run.xml      # Rider run configuration
```
