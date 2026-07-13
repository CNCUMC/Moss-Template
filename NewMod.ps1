<#
.SYNOPSIS
    从 Moss-Template 创建新的 Casualties Unknown 模组项目。

.DESCRIPTION
    使用 dotnet new mosstemplate 模板生成新模组项目，并自动配置所有参数。
    自动检测 Steam 安装路径中的游戏目录。
    运行前会自动从当前目录安装模板，无需手动执行 dotnet new install。

.PARAMETER ModName
    模组的 PascalCase 命名空间名称（如 "MyCoolMod"），将作为项目名和命名空间。
    不能包含空格。

.PARAMETER ModDisplayName
    模组的显示名称（如 "My Cool Mod"），用于 BepInEx 插件注册。
    如果不指定，将自动从 ModName 按大驼峰拆分生成。

.PARAMETER ModGuid
    模组的唯一 GUID，格式为 "yourname.modname"（如 "com.example.mymod"）。

.PARAMETER ModVersion
    模组的初始版本号（如 "1.0.0"）。

.PARAMETER AuthorName
    作者名称，用于 LICENSE 文件。

.PARAMETER GameRootPath
    游戏根目录的完整路径。如果不指定，将自动从 Steam 常见安装路径中检测。

.PARAMETER Language
    脚本界面语言 ("zh-CN" 或 "en-US")。

.PARAMETER OutputDir
    项目输出目录。如果不指定，则使用当前目录下与 ModName 同名的子目录。

.EXAMPLE
    .\NewMod.ps1 -ModName "MyCoolMod" -ModGuid "com.example.mymod"

.EXAMPLE
    .\NewMod.ps1 -Language zh-CN
    # 交互式输入，中文界面

.NOTES
    需要已安装 .NET SDK。模板会自动从当前目录安装，无需手动执行 dotnet new install。
#>
param(
    [string]$ModName,
    [string]$ModDisplayName,
    [string]$ModGuid,
    [string]$ModVersion,
    [string]$AuthorName,
    [string]$GameRootPath,
    [string]$LicenseType,
    [string]$Language = "en-US",
    [string]$OutputDir
)

# ============================================================
# 字符串资源 (NewMod.ps1 界面)
# ============================================================

$UIStrings = @{
    'zh-CN' = @{
        Title              = "Casualties Unknown Mod Creator"
        Subtitle           = "Moss-Template 模组创建向导"
        NamespacePrompt    = "输入模组命名空间 (PascalCase, 不能有空格, 如 MyCoolMod)"
        NamespaceError     = "命名空间不能包含空格"
        DisplayNamePrompt  = "输入模组显示名称"
        GuidPrompt         = "输入模组 GUID (格式: yourname.modname)"
        VersionPrompt      = "输入模组版本号"
        AuthorPrompt       = "输入作者名称 (用于 LICENSE)"
        LicenseChoice      = "选择许可证:"
        LicenseMIT         = "1. MIT (宽松，推荐大多数情况)"
        LicenseGPL         = "2. GPL v3 (要求衍生作品也开源)"
        LicenseLGPL        = "3. LGPL v3 (允许闭源使用，修改需开源)"
        LicenseInput       = "输入选择 (1-3, 默认: 1)"
        SearchingGame      = "正在搜索 Casualties Unknown 游戏路径..."
        GameFound          = "已找到游戏目录"
        GameNotFound       = "未自动找到游戏目录，请手动输入。"
        GamePathPrompt     = "输入游戏根目录路径"
        GamePathDefault    = "如 E:/SteamLibrary/steamapps/common/Casualties Unknown Demo"
        GamePathNotExist   = "游戏目录不存在"
        NeedManualFix      = "项目将被创建，但你需要手动修改 Directory.Build.props 中的游戏路径。"
        OutputDirPrompt    = "输入项目输出目录"
        ConfigSummary      = "配置摘要"
        SummaryNamespace   = "命名空间/项目名"
        SummaryDisplay     = "显示名称"
        SummaryGUID        = "GUID"
        SummaryVersion     = "版本号"
        SummaryAuthor      = "作者"
        SummaryGameDir     = "游戏根目录"
        SummaryOutput      = "输出目录"
        ConfirmCreate      = "确认创建? (Y/n)"
        Cancelled          = "已取消。"
        CreatingProject    = "正在创建项目..."
        TemplateNotReg     = "如果 mosstemplate 模板未安装，请先执行以下命令注册:"
        FilledRelease      = "已填入 Release.ps1 模组信息"
        GPLUsed            = "已使用 GPL v3 许可证: LICENSE.md"
        LGPLUsed           = "已使用 LGPL v3 许可证: LICENSE.md"
        MITUsed            = "已使用 MIT 许可证: LICENSE.md"
        LicenseTypeLabel   = "许可证类型"
        PropsCreated       = "已创建: Directory.Build.props"
        CleaningGit        = "清理模板 Git 仓库..."
        InitGit            = "初始化新 Git 仓库..."
        GitInitDone        = "Git 仓库已初始化并完成首次提交。"
        GitInitFail        = "Git 初始化失败"
        RiderConfig        = "生成 Rider 运行配置..."
        RiderCreated       = "已创建: .run/StartGame.run.xml"
        Success            = "项目创建成功!"
        NextSteps          = "下一步"
        Step1              = "1. cd $OutputDir"
        Step2              = "2. 编辑 Directory.Build.props 填写游戏路径"
        Step3              = "3. dotnet build  (验证编译)"
        Step4              = "4. 右键 StartGame.ps1 运行测试"
        DefaultAuthor      = "Your Name"
        DefaultVersion     = "1.0.0"
        DefaultGUIDPrefix  = "com.example."
        DefaultOutput      = ""
        InstallingTemplate = "正在安装模板..."
        TemplateInstalled  = "模板安装完成。"
        TemplateInstallFail = "模板安装失败。"
    }
    'en-US' = @{
        Title              = "Casualties Unknown Mod Creator"
        Subtitle           = "Moss-Template Mod Creation Wizard"
        NamespacePrompt    = "Enter mod namespace (PascalCase, no spaces, e.g. MyCoolMod)"
        NamespaceError     = "Namespace cannot contain spaces"
        DisplayNamePrompt  = "Enter mod display name"
        GuidPrompt         = "Enter mod GUID (format: yourname.modname)"
        VersionPrompt      = "Enter mod version"
        AuthorPrompt       = "Enter author name (for LICENSE)"
        LicenseChoice      = "Choose license:"
        LicenseMIT         = "1. MIT (permissive, recommended for most cases)"
        LicenseGPL         = "2. GPL v3 (requires derivative works to be open source)"
        LicenseLGPL        = "3. LGPL v3 (allows closed-source use, modifications must be open)"
        LicenseInput       = "Enter choice (1-3, default: 1)"
        SearchingGame      = "Searching for Casualties Unknown game directory..."
        GameFound          = "Found game directory"
        GameNotFound       = "Game directory not found automatically."
        GamePathPrompt     = "Enter game root directory path"
        GamePathDefault    = "e.g. E:/SteamLibrary/steamapps/common/Casualties Unknown Demo"
        GamePathNotExist   = "Game directory does not exist"
        NeedManualFix      = "Project will be created, but you need to manually fix the game path in Directory.Build.props."
        OutputDirPrompt    = "Enter project output directory"
        ConfigSummary      = "Configuration Summary"
        SummaryNamespace   = "Namespace/Project"
        SummaryDisplay     = "Display Name"
        SummaryGUID        = "GUID"
        SummaryVersion     = "Version"
        SummaryAuthor      = "Author"
        SummaryGameDir     = "Game Directory"
        SummaryOutput      = "Output Directory"
        ConfirmCreate      = "Proceed? (Y/n)"
        Cancelled          = "Cancelled."
        CreatingProject    = "Creating project..."
        TemplateNotReg     = "If mosstemplate is not installed, run:"
        FilledRelease      = "Filled Release.ps1 mod info"
        GPLUsed            = "Using GPL v3 license: LICENSE.md"
        LGPLUsed           = "Using LGPL v3 license: LICENSE.md"
        MITUsed            = "Using MIT license: LICENSE.md"
        LicenseTypeLabel   = "License Type"
        PropsCreated       = "Created: Directory.Build.props"
        CleaningGit        = "Cleaning template git repository..."
        InitGit            = "Initializing new git repository..."
        GitInitDone        = "Git repository initialized with first commit."
        GitInitFail        = "Git init failed"
        RiderConfig        = "Generating Rider run configuration..."
        RiderCreated       = "Created: .run/StartGame.run.xml"
        Success            = "Project created successfully!"
        NextSteps          = "Next steps"
        Step1              = "1. cd $OutputDir"
        Step2              = "2. Edit Directory.Build.props to set game path"
        Step3              = "3. dotnet build  (verify compilation)"
        Step4              = "4. Right-click StartGame.ps1 to run"
        DefaultAuthor      = "Your Name"
        DefaultVersion     = "1.0.0"
        DefaultGUIDPrefix  = "com.example."
        DefaultOutput      = ""
        InstallingTemplate = "Installing template..."
        TemplateInstalled  = "Template installed."
        TemplateInstallFail = "Template installation failed."
    }
}

# ============================================================
# 生成脚本的本地化字符串 (Release.ps1 / StartGame.ps1): EN -> ZH
# ============================================================

$ScriptI18n = @{
    "Release.ps1" = @{
        "Mod Info:" = "模组信息:"
        "Namespace:" = "命名空间:"
        "Display Name:" = "显示名称:"
        "Version:" = "版本号:"
        "Enter version (default:" = "输入版本号 (默认:"
        "Building project" = "构建项目"
        "Build failed" = "构建失败"
        "Build succeeded" = "构建成功"
        "Collecting files and creating archive" = "收集文件并创建压缩包"
        "Added: $ModNamespace.dll" = "已添加: $ModNamespace.dll"
        "DLL not found:" = "未找到 DLL:"
        "Added: $doc" = "已添加: $doc"
        "Read release notes from CHANGELOG.md" = "从 CHANGELOG.md 读取发布说明"
        "Generated NexusMods BBCode release notes" = "已生成 NexusMods BBCode 发布说明"
        "Added from deploy dir:" = "从部署目录添加:"
        "Failed to copy document files:" = "复制文档文件失败:"
        "Archive: $zipName" = "压缩包: $zipName"
        "Uploading to NexusMods..." = "上传到 NexusMods..."
        "NexusMods API Key not set." = "未设置 NexusMods API Key。"
        "NexusMods Mod ID not set." = "未设置 NexusMods Mod ID。"
        "Creating upload session..." = "创建上传会话..."
        "Upload session created:" = "上传会话已创建:"
        "Uploading file" = "上传文件中"
        "Archive created:" = "压缩包已生成:"
        "Please upload manually via NexusMods website." = "请通过 NexusMods 网页手动上传。"
        "File uploaded" = "文件已上传"
        "Finalizing upload..." = "确认上传..."
        "Upload finalized" = "上传已确认"
        "Creating mod file entry..." = "创建 Mod 文件条目..."
        "Mod file created" = "Mod 文件已创建"
        "NexusMods upload complete!" = "NexusMods 上传完成!"
        "NexusMods upload failed:" = "NexusMods 上传失败:"
        "API response:" = "API 响应:"
        "Uploading to GitHub Release..." = "上传到 GitHub Release..."
        "gh CLI not installed." = "gh CLI 未安装。"
        "gh not authenticated." = "gh 未认证。"
        "Running: gh" = "执行: gh"
        "GitHub Release created:" = "GitHub Release 已创建:"
        "GitHub Release creation failed" = "GitHub Release 创建失败"
        "GitHub Release failed:" = "GitHub Release 失败:"
        "Release complete!" = "发布完成!"
        "Size:" = "大小:"
    }
    "StartGame.ps1" = @{
        "Game path invalid or not a directory:" = "游戏路径无效或不是目录:"
        "Copying BepInEx logs to" = "正在复制 BepInEx 日志到"
        "Failed to copy BepInEx logs:" = "复制 BepInEx 日志失败:"
        "Cleared previous game logs." = "已清空之前的日志文件。"
        "Game path: $GamePath" = "游戏路径: $GamePath"
        "Mod namespace: $ModNamespace" = "模组命名空间: $ModNamespace"
        "Mod name: $ModName" = "模组名称: $ModName"
        "Target folder: $targetModFolder" = "目标文件夹: $targetModFolder"
        "Copying mod DLL to" = "正在复制模组 DLL 到"
        "Failed to copy mod DLL:" = "复制模组 DLL 失败:"
        "Copying document file" = "正在复制文档文件"
        "Document file" = "文档文件"
        "not found, skipping." = "不存在，跳过。"
        "Successfully copied" = "已成功复制"
        "document file(s) to plugin directory." = "个文档文件到插件目录。"
        "Failed to copy document files:" = "复制文档文件失败:"
        "Game process started, PID:" = "游戏进程已启动, PID:"
        "Game process exited." = "游戏进程已退出。"
        "Failed to start the game process:" = "启动游戏进程失败:"
        "Terminating game process..." = "正在终止游戏进程..."
    }
}

$Lang = $UIStrings[$Language]
if (-not $Lang) {
    $Lang = $UIStrings["en-US"]
}

function Get-Str {
    param([string]$Key)
    return $Lang[$Key]
}

# ============================================================
# 辅助函数
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
        "D:\SteamLibrary", "E:\SteamLibrary", "F:\SteamLibrary",
        "D:\Steam", "E:\Steam", "F:\Steam"
    )
    try {
        $steamRegPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam" -Name "InstallPath" -ErrorAction SilentlyContinue
        if ($steamRegPath -and $steamRegPath.InstallPath) {
            $steamCandidates = @($steamRegPath.InstallPath) + $steamCandidates
        }
    } catch { }

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

    $allCandidates = @()
    foreach ($lib in $libraryFolders) {
        $allCandidates += Join-Path $lib $gameRelativePath
    }
    foreach ($steamRoot in $steamCandidates) {
        $allCandidates += Join-Path $steamRoot $gameRelativePath
    }

    foreach ($candidate in $allCandidates) {
        $normalizedPath = $candidate.Replace('\', '/')
        if (Test-Path $normalizedPath -PathType Container) {
            return $normalizedPath
        }
    }
    return $null
}

function Localize-ScriptFile {
    param(
        [string]$ScriptPath,
        [string]$FileName
    )
    
    if (-not (Test-Path $ScriptPath)) { return }
    
    $i18nMap = $ScriptI18n[$FileName]
    if (-not $i18nMap) { return }
    
    $content = [System.IO.File]::ReadAllText($ScriptPath, [System.Text.Encoding]::UTF8)
    
    foreach ($english in $i18nMap.Keys) {
        $chinese = $i18nMap[$english]
        if ($Language -eq "zh-CN") {
            $content = $content.Replace($english, $chinese)
        }
    }
    
    [System.IO.File]::WriteAllText($ScriptPath, $content, [System.Text.UTF8Encoding]::new($true))
}

# ============================================================
# 自动安装模板
# ============================================================

$templateDir = $PSScriptRoot

Write-Host ""
Write-Host (Get-Str 'InstallingTemplate') -ForegroundColor Cyan

try {
    $installResult = & dotnet new install $templateDir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "$(Get-Str 'TemplateInstallFail') $installResult"
    } else {
        Write-Host (Get-Str 'TemplateInstalled') -ForegroundColor Green
    }
} catch {
    Write-Warning "$(Get-Str 'TemplateInstallFail') $_"
}

# ============================================================
# 设置编码
# ============================================================
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 > $null

# ============================================================
# 交互式输入缺失的参数
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  $(Get-Str 'Title')" -ForegroundColor Cyan
Write-Host "  $(Get-Str 'Subtitle')" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($ModName)) {
    $ModName = Read-Input -Prompt (Get-Str 'NamespacePrompt') -Required
}

if ($ModName -match '\s') {
    Write-Error "$(Get-Str 'NamespaceError'): '$ModName'"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($ModDisplayName)) {
    $autoDisplayName = Convert-ToDisplayName -Name $ModName
    $ModDisplayName = Read-Input -Prompt (Get-Str 'DisplayNamePrompt') -DefaultValue $autoDisplayName
}

if ([string]::IsNullOrWhiteSpace($ModGuid)) {
    $defaultGuid = "com.example.$($ModName.ToLower())"
    $ModGuid = Read-Input -Prompt (Get-Str 'GuidPrompt') -DefaultValue $defaultGuid -Required
}

if ([string]::IsNullOrWhiteSpace($ModVersion)) {
    $ModVersion = Read-Input -Prompt (Get-Str 'VersionPrompt') -DefaultValue (Get-Str 'DefaultVersion')
}

if ([string]::IsNullOrWhiteSpace($AuthorName)) {
    $AuthorName = Read-Input -Prompt (Get-Str 'AuthorPrompt') -DefaultValue (Get-Str 'DefaultAuthor')
}

if ([string]::IsNullOrWhiteSpace($LicenseType)) {
    Write-Host ""
    Write-Host (Get-Str 'LicenseChoice') -ForegroundColor Yellow
    Write-Host "  $(Get-Str 'LicenseMIT')" -ForegroundColor White
    Write-Host "  $(Get-Str 'LicenseGPL')" -ForegroundColor White
    Write-Host "  $(Get-Str 'LicenseLGPL')" -ForegroundColor White
    $choice = Read-Host (Get-Str 'LicenseInput')
    switch ($choice) {
        "2" { $LicenseType = "GPL-3.0" }
        "3" { $LicenseType = "LGPL-3.0" }
        default { $LicenseType = "MIT" }
    }
}

if ([string]::IsNullOrWhiteSpace($GameRootPath)) {
    Write-Host ""
    Write-Host (Get-Str 'SearchingGame') -ForegroundColor Cyan
    $detectedManagedPath = Find-GameManagedDir
    if ($detectedManagedPath) {
        $detectedRoot = (Resolve-Path (Join-Path $detectedManagedPath "..\..")).Path
        $detectedRoot = $detectedRoot.Replace('\', '/')
        Write-Host "  $(Get-Str 'GameFound'): $detectedRoot" -ForegroundColor Green
        $GameRootPath = Read-Input -Prompt (Get-Str 'GamePathPrompt') -DefaultValue $detectedRoot
    } else {
        Write-Host "  $(Get-Str 'GameNotFound')" -ForegroundColor Yellow
        $GameRootPath = Read-Input -Prompt "$(Get-Str 'GamePathPrompt') ($(Get-Str 'GamePathDefault'))" -Required
    }
}

$GameRootPath = $GameRootPath.Replace('\', '/')
if (-not (Test-Path $GameRootPath -PathType Container)) {
    Write-Warning "$(Get-Str 'GamePathNotExist'): $GameRootPath"
    Write-Warning (Get-Str 'NeedManualFix')
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Read-Input -Prompt (Get-Str 'OutputDirPrompt') -DefaultValue $ModName
}

# ============================================================
# 显示配置摘要
# ============================================================

Write-Host ""
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host "$(Get-Str 'ConfigSummary'):" -ForegroundColor Yellow
Write-Host "  $(Get-Str 'SummaryNamespace'): $ModName" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryDisplay'): $ModDisplayName" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryGUID'): $ModGuid" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryVersion'): $ModVersion" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryAuthor'): $AuthorName" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryGameDir'): $GameRootPath" -ForegroundColor White
Write-Host "  $(Get-Str 'SummaryOutput'): $OutputDir" -ForegroundColor White
Write-Host "----------------------------------------" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host (Get-Str 'ConfirmCreate')
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host (Get-Str 'Cancelled') -ForegroundColor Red
    exit 0
}

# ============================================================
# 执行 dotnet new
# ============================================================

Write-Host ""
Write-Host (Get-Str 'CreatingProject') -ForegroundColor Cyan

$dotnetArgs = @(
    "new", "mosstemplate",
    "-n", $ModName,
    "--ModDisplayName", $ModDisplayName,
    "--ModGuid", $ModGuid,
    "--ModVersion", $ModVersion,
    "--AuthorName", $AuthorName,
    "--GameRootPath", $GameRootPath,
    "--ModNamespace", $ModName,
    "--Language", $Language,
    "-o", $OutputDir
)

Write-Host "  dotnet $($dotnetArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""

& dotnet @dotnetArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "dotnet new failed (exit code: $LASTEXITCODE)"
    Write-Host ""
    Write-Host (Get-Str 'TemplateNotReg') -ForegroundColor Yellow
    Write-Host "  dotnet new install <Moss-Template project path>" -ForegroundColor Yellow
    exit $LASTEXITCODE
}

# ============================================================
# 替换 Release.ps1 中的占位符
# ============================================================

$projectPath = Resolve-Path $OutputDir

$releasePs1Path = Join-Path $projectPath "Release.ps1"
if (Test-Path $releasePs1Path) {
    $releaseContent = [System.IO.File]::ReadAllText($releasePs1Path, [System.Text.Encoding]::UTF8)
    $releaseContent = $releaseContent.Replace("__MOD_NAMESPACE__", $ModName)
    $releaseContent = $releaseContent.Replace("__MOD_DISPLAY_NAME__", $ModDisplayName)
    $releaseContent = $releaseContent.Replace("__MOD_VERSION__", $ModVersion)
    [System.IO.File]::WriteAllText($releasePs1Path, $releaseContent, [System.Text.UTF8Encoding]::new($true))
    Write-Host (Get-Str 'FilledRelease') -ForegroundColor Green
}

# ============================================================
# 本地化 Release.ps1 和 StartGame.ps1
# ============================================================

Localize-ScriptFile -ScriptPath (Join-Path $projectPath "Release.ps1") -FileName "Release.ps1"
Localize-ScriptFile -ScriptPath (Join-Path $projectPath "StartGame.ps1") -FileName "StartGame.ps1"

# ============================================================
# 处理 LICENSE 文件
# ============================================================

$licensePath = Join-Path $projectPath "LICENSE.md"

if ($LicenseType -eq "GPL-3.0") {
    $year = (Get-Date).Year
    $gpl3Content = @"
                    GNU GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

Copyright (C) $year $AuthorName

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warrantyof
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
"@
    [System.IO.File]::WriteAllText($licensePath, $gpl3Content, [System.Text.UTF8Encoding]::new($true))
    Write-Host (Get-Str 'GPLUsed') -ForegroundColor Green
} elseif ($LicenseType -eq "LGPL-3.0") {
    $year = (Get-Date).Year
    $lgpl3Content = @"
                  GNU LESSER GENERAL PUBLIC LICENSE
                       Version 3, 29 June 2007

 Copyright (C) $year $AuthorName

This version of the GNU Lesser Public License incorporates
the terms and conditions of version 3 of the GNU General Public
License, supplemented by the additional permissions listed below.

  0. Additional Definitions.

  As used herein, "this License" refers to version 3 of the GNU Lesser
General Public License, and the "GNU GPL" refers to version 3 of the GNU
General Public License.

  "The Library" refers to a covered work governed by this License,
other than an Application or a Combined Work as defined below.

  An "Application" is any work that makes use of an interface provided
by the Library, but which is not otherwise based on the Library.

  A "Combined Work" is a work produced by combining or linking an
Application with the Library.

  1. Exception to Section 3 of the GNU GPL.

  You may convey a covered work under sections 3 and 4 of this License
without being bound by section 3 of the GNU GPL.

  2. Conveying Modified Versions.

  If you modify a copy of the Library, you may convey a copy of the
modified version under this License or under the GNU GPL.

  3. Combined Works.

  You may convey a Combined Work under terms of your choice.

  4. Revised Versions of the GNU Lesser General Public License.

  The Free Software Foundation may publish revised and/or new versions
of the GNU Lesser General Public License from time to time.

  Each version is given a distinguishing version number. If the
Library as you received it specifies that a certain numbered version
of the GNU Lesser General Public License "or any later version"
applies to it, you have the option of following the terms and
conditions either of that published version or of any later version
published by the Free Software Foundation.

  If the Library as you received it specifies that a proxy can decide
whether future versions of the GNU Lesser General Public License shall
apply, that proxy's public statement of acceptance of any version is
permanent authorization for you to choose that version for the
Library.
"@
    [System.IO.File]::WriteAllText($licensePath, $lgpl3Content, [System.Text.UTF8Encoding]::new($true))
    Write-Host (Get-Str 'LGPLUsed') -ForegroundColor Green
} else {
    Write-Host (Get-Str 'MITUsed') -ForegroundColor Green
}

Write-Host "  $(Get-Str 'LicenseTypeLabel'): $LicenseType" -ForegroundColor Yellow

# ============================================================
# 复制 Directory.Build.props.example 为 Directory.Build.props
# ============================================================

$propsExamplePath = Join-Path $projectPath "Directory.Build.props.example"
$propsPath = Join-Path $projectPath "Directory.Build.props"

if (Test-Path $propsExamplePath) {
    Copy-Item $propsExamplePath $propsPath -Force
    Write-Host (Get-Str 'PropsCreated') -ForegroundColor Green
}

# ============================================================
# 清理模板 Git 并初始化新仓库
# ============================================================

$oldGitDir = Join-Path $projectPath ".git"
if (Test-Path $oldGitDir) {
    Write-Host (Get-Str 'CleaningGit') -ForegroundColor Cyan
    Remove-Item -Recurse -Force $oldGitDir
}

Write-Host (Get-Str 'InitGit') -ForegroundColor Cyan
Push-Location $projectPath
try {
    git init | Out-Null
    git add . | Out-Null
    git commit -m "Initial commit: $ModDisplayName mod" | Out-Null
    Write-Host "  $(Get-Str 'GitInitDone')" -ForegroundColor Green
} catch {
    Write-Warning "$(Get-Str 'GitInitFail'): $_"
}
Pop-Location

# ============================================================
# 生成 Rider 运行配置
# ============================================================

Write-Host (Get-Str 'RiderConfig') -ForegroundColor Cyan

$runDir = Join-Path $projectPath ".run"
if (-not (Test-Path $runDir)) {
    New-Item -ItemType Directory -Path $runDir -Force | Out-Null
}

$runConfig = @"
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="StartGame" type="PowerShellRunType" factoryName="PowerShell" scriptUrl="`$PROJECT_DIR$/StartGame.ps1" executablePath="C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe">
    <envs />
    <method v="2">
      <option name="Build Solution" enabled="true" />
    </method>
  </configuration>
</component>
"@

$runConfigPath = Join-Path $runDir "StartGame.run.xml"
[System.IO.File]::WriteAllText($runConfigPath, $runConfig, [System.Text.UTF8Encoding]::new($true))
Write-Host "  $(Get-Str 'RiderCreated')" -ForegroundColor Green

# ============================================================
# 完成
# ============================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  $(Get-Str 'Success')" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "$(Get-Str 'NextSteps'):" -ForegroundColor Yellow
Write-Host "  $(Get-Str 'Step1')" -ForegroundColor White
Write-Host "  $(Get-Str 'Step2')" -ForegroundColor White
Write-Host "  $(Get-Str 'Step3')" -ForegroundColor White
Write-Host "  $(Get-Str 'Step4')" -ForegroundColor White
Write-Host ""
