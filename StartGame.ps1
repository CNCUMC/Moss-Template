param(
    [string]$GamePath = "__GAME_ROOT_PATH__",
    [string]$ModNamespace = "__MOD_NAMESPACE__"
)

function Convert-ToDisplayName {
    param([string]$Namespace)
    if ([string]::IsNullOrWhiteSpace($Namespace)) { return $Namespace }

    $result = [System.Text.StringBuilder]::new()
    $chars = $Namespace.ToCharArray()
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $c = $chars[$i]
        if ($i -gt 0 -and [char]::IsUpper($c) -and [char]::IsLower($chars[$i-1])) {
            $result.Append(' ') | Out-Null
        }
        $result.Append($c) | Out-Null
    }
    return $result.ToString()
}

$ModName = Convert-ToDisplayName -Namespace $ModNamespace

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

$timestamp = Get-Date -Format "yyyy-MM-dd_HH.mm.ss"

$GamePath = [System.IO.Path]::GetFullPath($GamePath)
$bepInExPath = [System.IO.Path]::Combine($GamePath, "BepInEx")

$GameLog = Join-Path $env:USERPROFILE "AppData\LocalLow\Orsoniks\CasualtiesUnknown\Player.log"
$GameExecutable = [System.IO.Path]::Combine($GamePath, "CasualtiesUnknown.exe")
$ModDll = [System.IO.Path]::Combine($PSScriptRoot, "bin/Debug/net472", "$ModNamespace.dll")

$targetModFolder = $ModName

$docFiles = @("README.md", "README_ZH.md", "LICENSE.md", "CHANGELOG.md", "CHANGELOG_ZH.md")

$logDestination = [System.IO.Path]::Combine($PSScriptRoot, "Logs", "$timestamp.log")

if (-not (Test-Path $GamePath -PathType Container))
{
    Write-Error "Game path invalid or not a directory: $GamePath"
    exit 1
}

$logsFolder = [System.IO.Path]::Combine($PSScriptRoot, "Logs")
if (-not (Test-Path $logsFolder))
{
    New-Item -ItemType Directory -Path $logsFolder -Force
}

function Write-ColoredMessage
{
    param (
        [string]$Message,
        [System.ConsoleColor]$Color
    )
    Write-Host $Message -ForegroundColor $Color
}

function Copy-BepInExLog
{
    if (Test-Path $GameLog)
    {
        try
        {
            Copy-Item $GameLog $logDestination -Force
            Write-ColoredMessage "Copying BepInEx logs to ""$logDestination""." Cyan
        }
        catch
        {
            Write-Warning "Failed to copy BepInEx logs: $_"
        }
    }
}

function Interval
{
    Write-Host "----------------------------------------"
}

if (Test-Path $GameLog)
{
    Clear-Content $GameLog
    Write-ColoredMessage "Cleared previous game logs." Cyan
}

Write-ColoredMessage "Game path: $GamePath" Yellow
Write-ColoredMessage "Mod namespace: $ModNamespace" Yellow
Write-ColoredMessage "Mod name: $ModName" Yellow
Write-ColoredMessage "Target folder: $targetModFolder" Yellow

try
{
    $pluginPath = [System.IO.Path]::Combine($bepInExPath, "plugins", $targetModFolder)
    New-Item -ItemType Directory -Path $pluginPath -Force
    Copy-Item $ModDll ([System.IO.Path]::Combine($pluginPath, "$ModNamespace.dll")) -Force
    Write-ColoredMessage "Copying mod DLL to ""$pluginPath\$ModNamespace.dll""." Cyan
}
catch
{
    Write-Error "Failed to copy mod DLL: $_"
    exit 1
}

try
{
    $destDocPath = [System.IO.Path]::Combine($bepInExPath, "plugins", $targetModFolder)
    $copiedDocs = 0

    foreach ($docFile in $docFiles)
    {
        $sourceDocPath = [System.IO.Path]::Combine($PSScriptRoot, $docFile)
        $destDocFilePath = [System.IO.Path]::Combine($destDocPath, $docFile)

        if (Test-Path $sourceDocPath -PathType Leaf)
        {
            Copy-Item $sourceDocPath $destDocFilePath -Force
            Write-ColoredMessage "Copying document file ""$docFile"" to ""$destDocFilePath""." Cyan
            $copiedDocs++
        }
        else
        {
            Write-ColoredMessage "Document file ""$docFile"" not found, skipping." Yellow
        }
    }

    if ($copiedDocs -gt 0)
    {
        Write-ColoredMessage "Successfully copied $copiedDocs document file(s) to plugin directory." Green
    }
}
catch
{
    Write-Warning "Failed to copy document files: $_"
}

try
{
    $gameProcess = Start-Process -FilePath $GameExecutable `
        -WorkingDirectory (Split-Path $GameExecutable -Parent) `
        -PassThru -NoNewWindow

    Write-ColoredMessage "Game process started, PID: $( $gameProcess.Id )" Yellow
    Interval

    $lastReadPosition = 0
    while (!$gameProcess.HasExited)
    {
        if (Test-Path $GameLog)
        {
            $content = Get-Content $GameLog -ReadCount 0 -Encoding UTF8
            for ($i = $lastReadPosition; $i -lt $content.Count; $i++) {
                $line = $content[$i]
                $color = "White"
                if ($line -match "^\[Error") { $color = "Red" }
                elseif ($line -match "^\[Warning") { $color = "Yellow" }
                elseif ($line -match "^\[Info") { $color = "White" }
                elseif ($line -match "^\[Message") { $color = "Blue" }
                Write-ColoredMessage $line $color
            }
            $lastReadPosition = $content.Count
        }
        Start-Sleep -Milliseconds 500
    }

    Interval
    Write-ColoredMessage "Game process exited." Red
}

catch
{
    Write-Error "Failed to start the game process: $_"
    exit 1
}

finally
{
    if ($gameProcess -and !$gameProcess.HasExited)
    {
        Interval
        Write-ColoredMessage "Terminating game process..." Red
        $gameProcess.Kill()
    }
    Copy-BepInExLog
}
