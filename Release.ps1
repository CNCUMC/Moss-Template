<#
.SYNOPSIS
    Build and publish mod to NexusMods and/or GitHub Release.

.DESCRIPTION
    1. Read mod info from Plugin.cs (Name, Version, GUID)
    2. Build project
    3. Collect files and compress to {Name}-v{Version}.zip
    4. Upload to NexusMods (via API)
    5. Upload to GitHub Release (via gh CLI)

.PARAMETER Configuration
    Build configuration (Debug/Release), default Release.

.PARAMETER NexusApiKey
    NexusMods API Key. Can also be set via NEXUS_API_KEY environment variable.

.PARAMETER GamePath
    Game path for collecting deployed files from BepInEx/plugins.
    If not specified, only collect from project directory.

.PARAMETER SkipBuild
    Skip build step.

.PARAMETER SkipNexus
    Skip NexusMods upload.

.PARAMETER SkipGitHub
    Skip GitHub Release.

.PARAMETER ReleaseNotes
    GitHub Release notes content.

.PARAMETER Prerelease
    Mark as GitHub pre-release.

.EXAMPLE
    .\Release.ps1

.EXAMPLE
    .\Release.ps1 -SkipNexus -ReleaseNotes "Fixed several issues."

.NOTES
    GitHub Release requires gh CLI: winget install GitHub.cli
#>
param(
    [string]$ModNamespace = "__MOD_NAMESPACE__",
    [string]$ModDisplayName = "__MOD_DISPLAY_NAME__",
    [string]$ModVersion = "__MOD_VERSION__",
    [int]$NexusModId = 0,
    [string]$Configuration = "Release",
    [string]$NexusApiKey = $env:NEXUS_API_KEY,
    [string]$GamePath,
    [switch]$SkipBuild,
    [switch]$SkipNexus,
    [switch]$SkipGitHub,
    [string]$ReleaseNotes,
    [switch]$Prerelease
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot

# ============================================================
# Helper functions
# ============================================================

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host ">>> $Message" -ForegroundColor $Color
}

function Write-OK {
    param([string]$Message)
    Write-Host "    OK: $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "    FAIL: $Message" -ForegroundColor Red
}

function Convert-MarkdownToNexusBBCode {
    param([string]$Markdown)
    
    $result = $Markdown
    
    $result = $result -replace '(?m)^###\s+(.+)$', '[size=3][b]$1[/b][/size]'
    $result = $result -replace '(?m)^##\s+(.+)$', '[size=4][b]$1[/b][/size]'
    $result = $result -replace '(?m)^#\s+(.+)$', '[size=5][b]$1[/b][/size]'
    $result = $result -replace '\*\*(.+?)\*\*', '[b]$1[/b]'
    $result = $result -replace '(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', '[i]$1[/i]'
    $result = $result -replace '~~(.+?)~~', '[s]$1[/s]'
    $result = $result -replace '`([^`]+)`', '[code]$1[/code]'
    $result = $result -replace '\[([^\]]+)\]\(([^)]+)\)', '[url=$2]$1[/url]'
    $result = $result -replace '(?m)^-\s+(.+)$', '[*]$1[/*]'
    $result = $result -replace '(?m)^\d+\.\s+(.+)$', '[*]$1[/*]'
    $result = $result -replace '(?m)^>\s?(.+)$', '[quote]$1[/quote]'
    $result = $result -replace '(?m)^---\s*$', '[line]'
    
    return $result
}

# ============================================================
# 1. Mod info (pre-filled by NewMod.ps1)
# ============================================================

Write-Step "Mod Info:" "Yellow"
Write-OK "Namespace:   $ModNamespace"
Write-OK "Display Name: $ModDisplayName"

$userVersion = Read-Host "Enter version (default: $ModVersion)"
if (-not [string]::IsNullOrWhiteSpace($userVersion)) {
    $ModVersion = $userVersion
}
Write-OK "Version:     $ModVersion"

$releasesDir = Join-Path $scriptDir "Releases"
if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir -Force | Out-Null
}

$zipName = "$ModDisplayName-v$ModVersion.zip"
$zipPath = Join-Path $releasesDir $zipName

# ============================================================
# 2. Build project
# ============================================================

if (-not $SkipBuild) {
    Write-Step "Building project ($Configuration)..." "Yellow"
    
    Push-Location $scriptDir
    try {
        $buildResult = & dotnet build -c $Configuration 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed:`n$buildResult"
            exit 1
        }
        Write-OK "Build succeeded"
    } finally {
        Pop-Location
    }
}

# ============================================================
# 3. Collect files and compress
# ============================================================

Write-Step "Collecting files and creating archive..." "Yellow"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "MossRelease_$([System.Guid]::NewGuid())"
$packageDir = Join-Path $tempDir "package"
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

$buildOutputDir = Join-Path $scriptDir "bin/$Configuration/net472"
$dllSource = Join-Path $buildOutputDir "$ModNamespace.dll"

if (Test-Path $dllSource) {
    Copy-Item $dllSource $packageDir -Force
    Write-OK "Added: $ModNamespace.dll"
} else {
    Write-Warning "DLL not found: $dllSource"
}

$docFiles = @("README.md", "README_ZH.md", "LICENSE.md", "CHANGELOG.md", "CHANGELOG_ZH.md")
foreach ($doc in $docFiles) {
    $docPath = Join-Path $scriptDir $doc
    if (Test-Path $docPath) {
        Copy-Item $docPath $packageDir -Force
        Write-OK "Added: $doc"
    }
}

if ([string]::IsNullOrWhiteSpace($ReleaseNotes)) {
    $changelogPath = Join-Path $scriptDir "CHANGELOG.md"
    if (Test-Path $changelogPath) {
        $changelogContent = Get-Content $changelogPath -Raw -Encoding UTF8
        $pattern = "(##\s+v?$([regex]::Escape($ModVersion))[\s\S]*?)(?=##\s+v|`$)"
        if ($changelogContent -match $pattern) {
            $ReleaseNotes = $Matches[1].Trim()
            Write-OK "Read release notes from CHANGELOG.md"
        } else {
            $ReleaseNotes = ($changelogContent -split "`n" | Select-Object -First 20) -join "`n"
            Write-OK "Read release notes from CHANGELOG.md (first 20 lines)"
        }
    }
    
    if ($ReleaseNotes) {
        $NexusDescription = Convert-MarkdownToNexusBBCode -Markdown $ReleaseNotes
        Write-OK "Generated NexusMods BBCode release notes"
    }
}

if ($GamePath -and (Test-Path $GamePath)) {
    $deployedDir = Join-Path $GamePath "BepInEx/plugins/$ModDisplayName"
    if (Test-Path $deployedDir) {
        $extraFiles = Get-ChildItem $deployedDir -File | Where-Object { $_.Extension -ne ".dll" }
        foreach ($f in $extraFiles) {
            Copy-Item $f.FullName $packageDir -Force
            Write-OK "Added from deploy dir: $($f.Name)"
        }
    }
}

if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    Compress-Archive -Path "$packageDir/*" -DestinationPath $zipPath -Force
} else {
    Write-Error "Compress-Archive not available"
    exit 1
}

$zipSize = (Get-Item $zipPath).Length
$zipSizeMB = [math]::Round($zipSize / 1MB, 2)
Write-OK "Archive: $zipName ($zipSizeMB MB)"

Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue

# ============================================================
# 4. Upload to NexusMods
# ============================================================

if (-not $SkipNexus) {
    Write-Step "Uploading to NexusMods..." "Yellow"

    if ([string]::IsNullOrWhiteSpace($NexusApiKey)) {
        Write-Fail "NexusMods API Key not set. Set environment variable NEXUS_API_KEY or use -NexusApiKey parameter."
    } elseif ($NexusModId -eq 0) {
        Write-Fail "NexusMods Mod ID not set. Use -NexusModId parameter."
    } else {
        $nexusBase = "https://api.nexusmods.com/v3"
        $nexusHeaders = @{
            "apikey" = $NexusApiKey
            "Accept" = "application/json"
        }

        try {
            Write-Host "    Creating upload session..." -ForegroundColor DarkGray
            $createUploadBody = @{
                filename   = $zipName
                size_bytes = $zipSize
            } | ConvertTo-Json

            $uploadSession = Invoke-RestMethod -Uri "$nexusBase/uploads" `
                -Method Post -Headers $nexusHeaders `
                -Body $createUploadBody -ContentType "application/json"

            $uploadId = $uploadSession.data.id
            $presignedUrl = $uploadSession.data.presigned_url
            Write-OK "Upload session created: $uploadId"

            Write-Host "    Uploading file ($zipSizeMB MB)..." -ForegroundColor DarkGray

            $putClient = [System.Net.Http.HttpClient]::new()
            $fileBytes = [System.IO.File]::ReadAllBytes($zipPath)
            $byteContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)
            $byteContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
            $byteContent.Headers.ContentLength = $fileBytes.Length

            $putResponse = $putClient.PutAsync($presignedUrl, $byteContent).Result

            if (-not $putResponse.IsSuccessStatusCode) {
                Write-Host "    [Known issue] S3 presigned URL signature mismatch (NexusMods API bug)" -ForegroundColor Yellow
                Write-Host "    Archive created: $zipPath" -ForegroundColor Yellow
                Write-Host "    Please upload manually via NexusMods website." -ForegroundColor Yellow
                throw "S3 PUT failed: $($putResponse.StatusCode) - Please upload manually to NexusMods"
            }

            Write-OK "File uploaded"

            Write-Host "    Finalizing upload..." -ForegroundColor DarkGray
            Invoke-RestMethod -Uri "$nexusBase/uploads/$uploadId/finalise" `
                -Method Post -Headers $nexusHeaders | Out-Null
            Write-OK "Upload finalized"

            Write-Host "    Creating mod file entry..." -ForegroundColor DarkGray
            $createFileBody = @{
                upload_id     = $uploadId
                mod_id        = $NexusModId
                name          = "$ModDisplayName v$ModVersion"
                version       = $ModVersion
                file_category = 1
            }
            if ($NexusDescription) {
                $createFileBody["description"] = $NexusDescription
            }

            $modFile = Invoke-RestMethod -Uri "$nexusBase/mod-files" `
                -Method Post -Headers $nexusHeaders `
                -Body ($createFileBody | ConvertTo-Json) `
                -ContentType "application/json"

            Write-OK "Mod file created (ID: $($modFile.data.id))"
            Write-OK "NexusMods upload complete!"

        } catch {
            Write-Fail "NexusMods upload failed: $_"
            if ($_.Exception.Response) {
                try {
                    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                    $errorBody = $reader.ReadToEnd()
                    Write-Host "    API response: $errorBody" -ForegroundColor Red
                } catch {}
            }
        }
    }
}

# ============================================================
# 5. Upload to GitHub Release
# ============================================================

if (-not $SkipGitHub) {
    Write-Step "Uploading to GitHub Release..." "Yellow"

    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghAvailable) {
        Write-Fail "gh CLI not installed. Run: winget install GitHub.cli"
    } else {
        try {
            $ghAuth = & gh auth status 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "gh not authenticated. Run: gh auth login"
            } else {
                $tagName = "v$ModVersion"

                $ghArgs = @(
                    "release", "create", $tagName,
                    $zipPath,
                    "--title", "$ModDisplayName $tagName"
                )

                if ($ReleaseNotes) {
                    $ghArgs += @("--notes", $ReleaseNotes)
                } else {
                    $ghArgs += @("--generate-notes")
                }

                if ($Prerelease) {
                    $ghArgs += "--prerelease"
                }

                Write-Host "    Running: gh $($ghArgs -join ' ')" -ForegroundColor DarkGray
                & gh @ghArgs

                if ($LASTEXITCODE -eq 0) {
                    Write-OK "GitHub Release created: $tagName"
                } else {
                    Write-Fail "GitHub Release creation failed (exit code: $LASTEXITCODE)"
                }
            }
        } catch {
            Write-Fail "GitHub Release failed: $_"
        }
    }
}

# ============================================================
# Done
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Release complete!" -ForegroundColor Green
Write-Host "  Archive: $zipName" -ForegroundColor White
Write-Host "  Size:   $zipSizeMB MB" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
