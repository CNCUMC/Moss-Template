<#
.SYNOPSIS
    从 Moss-Template 创建新的 Casualties Unknown 模组项目。

.DESCRIPTION
    使用 dotnet new mosstemplate 模板生成新模组项目，并自动配置所有参数。
    自动检测 Steam 安装路径中的游戏 Managed 目录。

.PARAMETER ModName
    模组的 PascalCase 命名空间名称（如 "MyCoolMod"），将作为项目名和命名空间。
    不能包含空格。

.PARAMETER ModDisplayName
    模组的显示名称（如 "My Cool Mod"），用于 BepInEx 插件注册。
    如果不指定，将自动从 ModName 按大驼峰拆分生成。

.PARAMETER ModGuid
    模组的唯一 GUID，格式为 "yourname.modname"（如 "com.example.mycoolmod"）。

.PARAMETER ModVersion
    模组的初始版本号（如 "1.0.0"）。

.PARAMETER AuthorName
    作者名称，用于 LICENSE 文件。

.PARAMETER GameManagedDir
    游戏 Managed 目录的完整路径。如果不指定，将自动从 Steam 常见安装路径中检测。

.PARAMETER OutputDir
    项目输出目录。如果不指定，则使用当前目录下与 ModName 同名的子目录。

.EXAMPLE
    .\NewMod.ps1 -ModName "MyCoolMod" -ModGuid "com.example.mycoolmod"

.EXAMPLE
    .\NewMod.ps1
    # Interactive input with auto-detected game path

.NOTES
    Requires .NET SDK and the mosstemplate template to be installed.
    Install: dotnet new install <Moss-Template project path>
#>
param(
    [string]$ModName,
    [string]$ModDisplayName,
    [string]$ModGuid,
    [string]$ModVersion,
    [string]$AuthorName,
    [string]$GameManagedDir,
    [string]$OutputDir
)

# ============================================================
# Helper functions
# ============================================================

function Convert-ToDisplayName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $Name }
    $result = [System.Text.StringBuilder]::new()
    $chars = $Name.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $c = $chars[$i]
        if ($i -gt 0 -and [char]::IsUpper($c) -and [char]::IsLower($chars[$i - 1])) {
            $result.Append(' ') | Out-Null
        }
        $result.Append($c) | Out-Null
    }
    return $result.ToString()
}

function Read-Input {
    param(
        [string]$Prompt,
        [string]$DefaultValue,
        [switch]$Required
    )
    if ($DefaultValue) {
        $userInput = Read-Host "$Prompt (default: $DefaultValue)"
        if ([string]::IsNullOrWhiteSpace($userInput)) { return $DefaultValue }
    } else {
        $userInput = Read-Host $Prompt
    }
    if ($Required -and [string]::IsNullOrWhiteSpace($userInput)) {
        Write-Error "This field is required."
        exit 1
    }
    return $userInput
}

function Find-GameManagedDir {
    $gameRelativePath = "steamapps\common\Casualties Unknown Demo\CasualtiesUnknown_Data\Managed"

    $steamCandidates = @(
        "C:\Program Files (x86)\Steam",
        "D:\SteamLibrary",
        "E:\SteamLibrary",
        "F:\SteamLibrary",
        "D:\Steam",
        "E:\Steam",
        "F:\Steam"
    )

    # Read Steam install path from registry
    try {
        $steamRegPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue
        if ($steamRegPath -and $steamRegPath.InstallPath) {
            $steamCandidates = @($steamRegPath.InstallPath) + $steamCandidates
        }
    } catch { }

    # Parse libraryfolders.vdf for additional Steam library paths
    $libraryFolders = @()
    foreach ($steamRoot in $steamCandidates) {
        $vdfPath = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
        if (Test-Path $vdfPath) {
            try {
                $vdfContent = Get-Content $vdfPath -Raw
                $pattern = '"path"\s+"(.+?)"'
                $vdfMatches = [regex]::Matches($vdfContent, $pattern)
                foreach ($m in $vdfMatches) {
                    $libPath = $m.Groups[1].Value -replace '\\\\', '\'
                    if (-not $libraryFolders.Contains($libPath)) {
                        $libraryFolders += $libPath
                    }
                }
            } catch { }
        }
    }

    # Build candidate paths (library folders first, then static candidates)
    $allCandidates = @()
    foreach ($lib in $libraryFolders) {
        $allCandidates += Join-Path $lib $gameRelativePath
    }
    foreach ($steamRoot in $steamCandidates) {
        $allCandidates += Join-Path $steamRoot $gameRelativePath
    }

    # Return first existing path
    foreach ($candidate in $allCandidates) {
        $normalizedPath = $candidate.Replace('\', '/')
        if (Test-Path $normalizedPath -PathType Container) {
            return $normalizedPath
        }
    }

    return $null
}

# ============================================================
# Setup encoding
# ============================================================
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# ============================================================
# Interactive input for missing parameters
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Casualties Unknown Mod Creator" -ForegroundColor Cyan
Write-Host "  Moss-Template Mod Creation Wizard" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ModName - required
if ([string]::IsNullOrWhiteSpace($ModName)) {
    $ModName = Read-Input -Prompt "Enter mod namespace (PascalCase, no spaces, e.g. MyCoolMod)" -Required
}

# Validate namespace (no spaces)
if ($ModName -match '\s') {
    Write-Error "Namespace cannot contain spaces: '$ModName'"
    exit 1
}

# ModDisplayName - optional, auto-generated from ModName
if ([string]::IsNullOrWhiteSpace($ModDisplayName)) {
    $autoDisplayName = Convert-ToDisplayName -Name $ModName
    $ModDisplayName = Read-Input -Prompt "Enter mod display name" -DefaultValue $autoDisplayName
}

# ModGuid - required
if ([string]::IsNullOrWhiteSpace($ModGuid)) {
    $defaultGuid = "com.example.$($ModName.ToLower())"
    $ModGuid = Read-Input -Prompt "Enter mod GUID (format: yourname.modname)" -DefaultValue $defaultGuid -Required
}

# ModVersion - optional
if ([string]::IsNullOrWhiteSpace($ModVersion)) {
    $ModVersion = Read-Input -Prompt "Enter mod version" -DefaultValue "1.0.0"
}

# AuthorName - optional
if ([string]::IsNullOrWhiteSpace($AuthorName)) {
    $AuthorName = Read-Input -Prompt "Enter author name (for LICENSE)" -DefaultValue "Your Name"
}

# GameManagedDir - auto-detect
if ([string]::IsNullOrWhiteSpace($GameManagedDir)) {
    Write-Host ""
    Write-Host "Searching for Casualties Unknown game directory..." -ForegroundColor Cyan

    $detectedPath = Find-GameManagedDir

    if ($detectedPath) {
        Write-Host "  Found: $detectedPath" -ForegroundColor Green
        $GameManagedDir = Read-Input -Prompt "Enter game Managed directory path" -DefaultValue $detectedPath
    } else {
        Write-Host "  Game directory not found automatically." -ForegroundColor Yellow
        $GameManagedDir = Read-Input -Prompt "Enter game Managed directory path" -Required
    }
}

# Validate game path
$normalizedGameDir = $GameManagedDir.Replace('\', '/')
if (-not (Test-Path $normalizedGameDir -PathType Container)) {
    Write-Warning "Game directory does not exist: $GameManagedDir"
    Write-Warning "Project will be created, but you need to manually fix DLL reference paths in csproj."
}

# OutputDir - optional
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Read-Input -Prompt "Enter project output directory" -DefaultValue $ModName
}

# ============================================================
# Show config summary
# ============================================================

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "  Namespace/Project: $ModName" -ForegroundColor White
Write-Host "  Display Name:      $ModDisplayName" -ForegroundColor White
Write-Host "  GUID:              $ModGuid" -ForegroundColor White
Write-Host "  Version:           $ModVersion" -ForegroundColor White
Write-Host "  Author:            $AuthorName" -ForegroundColor White
Write-Host "  Game Directory:    $GameManagedDir" -ForegroundColor White
Write-Host "  Output Directory:  $OutputDir" -ForegroundColor White
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Proceed? (Y/n)"
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host "Cancelled." -ForegroundColor Red
    exit 0
}

# ============================================================
# Execute dotnet new
# ============================================================

Write-Host ""
Write-Host "Creating project..." -ForegroundColor Cyan

# Normalize path separators for csproj
$GameManagedDirNormalized = $GameManagedDir.Replace('\', '/')

$dotnetArgs = @(
    "new", "mosstemplate",
    "-n", $ModName,
    "--ModDisplayName", $ModDisplayName,
    "--ModGuid", $ModGuid,
    "--ModVersion", $ModVersion,
    "--AuthorName", $AuthorName,
    "--GameManagedDir", $GameManagedDirNormalized,
    "-o", $OutputDir
)

Write-Host "  Running: dotnet $($dotnetArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""

& dotnet @dotnetArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet new failed (exit code: $LASTEXITCODE)"
    Write-Host ""
    Write-Host "If mosstemplate is not installed, run:" -ForegroundColor Yellow
    Write-Host "  dotnet new install <Moss-Template project path>" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

# ============================================================
# Clean template git and init new repo
# ============================================================

$projectPath = Resolve-Path $OutputDir

# Remove template .git directory if present
$oldGitDir = Join-Path $projectPath ".git"
if (Test-Path $oldGitDir) {
    Write-Host "Cleaning template git repository..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force $oldGitDir
}

# Initialize new git repository
Write-Host "Initializing new git repository..." -ForegroundColor Cyan
Push-Location $projectPath
try {
    git init | Out-Null
    git add . | Out-Null
    git commit -m "Initial commit: $ModDisplayName mod" | Out-Null
    Write-Host "  Git repository initialized with first commit." -ForegroundColor Green
} catch {
    Write-Warning "Git init failed: $_"
}
Pop-Location

# ============================================================
# Done
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Project created successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. cd $OutputDir" -ForegroundColor White
Write-Host "  2. dotnet build  (verify compilation)" -ForegroundColor White
Write-Host "  3. Right-click StartGame.ps1 to run" -ForegroundColor White
Write-Host ""
