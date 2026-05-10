# add.ps1 — 把一个配置文件/文件夹加入包管理器
# 用法: .\add.ps1 <名称> <原始路径>

param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Source
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Root = Split-Path -Parent $ScriptDir
$ConfigDir = Join-Path $Root "config"
$ManifestPath = Join-Path $Root "manifest.json"

# 读取 manifest
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

if ($manifest.packages.PSObject.Properties.Name -contains $Name) {
    Write-Host "[$Name] 已存在于 manifest 中，跳过" -ForegroundColor Yellow
    exit
}

New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
$Source = [System.IO.Path]::GetFullPath($Source)

if (-not (Test-Path $Source)) {
    Write-Host "源路径不存在: $Source" -ForegroundColor Red
    exit
}

$item = Get-Item $Source
$isFile = -not $item.PSIsContainer

# 确定 Target 路径
$Target = Join-Path $ConfigDir $Name
if ($isFile) {
    $Target = Join-Path $ConfigDir "$Name$($item.Extension)"
}

# 解析已有 symlink/junction
$realSource = $Source
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $resolved = $item.Target
    if ($resolved) {
        $realSource = if ([System.IO.Path]::IsPathRooted($resolved)) { $resolved } else { Join-Path (Split-Path $Source -Parent) $resolved }
        Write-Host "[$Name] 原路径是 reparse point，解析到: $realSource" -ForegroundColor Cyan
    }
}

# 如果源已在 config 内，跳过移动
$configPath = (Get-Item $ConfigDir).FullName
if (-not $realSource.StartsWith($configPath, [StringComparison]::OrdinalIgnoreCase)) {
    Move-Item -Path $realSource -Destination $Target -Force
    Write-Host "[$Name] 移动: $realSource -> $Target" -ForegroundColor Green
} else {
    Write-Host "[$Name] 已在 config/ 中，跳过移动" -ForegroundColor Cyan
    $Target = $realSource
}

# 删除原路径（如果还在）
if (Test-Path $Source) { Remove-Item $Source -Force -Recurse }

# 创建链接
$parent = Split-Path $Source -Parent
if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

if ($isFile) {
    # 文件用 Hardlink
    New-Item -ItemType HardLink -Path $Source -Target $Target | Out-Null
    Write-Host "[$Name] HardLink: $Source -> $Target" -ForegroundColor Green
} else {
    # 文件夹用 Junction（不需要管理员权限）
    New-Item -ItemType Junction -Path $Source -Target $Target | Out-Null
    Write-Host "[$Name] Junction: $Source -> $Target" -ForegroundColor Green
}

# 更新 manifest
$manifest.packages | Add-Member -NotePropertyName $Name -NotePropertyValue @{
    target = $Target.Replace($Root, '.').Replace('\', '/')
    link   = $Source
    type   = if ($isFile) { "file" } else { "dir" }
} -Force

$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "[$Name] 已写入 manifest" -ForegroundColor Green
