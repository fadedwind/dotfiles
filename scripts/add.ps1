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

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

if ($manifest.packages.PSObject.Properties.Name -contains $Name) {
    Write-Host "[$Name] 已存在，跳过" -ForegroundColor Yellow
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

# 确定 Target
$Target = Join-Path $ConfigDir $Name
if ($isFile) {
    $Target = Join-Path $ConfigDir "$Name$($item.Extension)"
}

# 解析已有 junction/symlink
$realSource = $Source
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $resolved = $item.Target
    if ($resolved) {
        $realSource = if ([System.IO.Path]::IsPathRooted($resolved)) { $resolved } else { Join-Path (Split-Path $Source -Parent) $resolved }
    }
}

$configPath = (Get-Item $ConfigDir).FullName

if ($isFile) {
    # 文件：跨盘符不能 HardLink/Junction，用复制+定期同步
    # 把文件复制到 config 目录，原位不动
    Copy-Item -Path $Source -Destination $Target -Force
    Write-Host "[$Name] 已复制: $Source -> $Target" -ForegroundColor Green
    Write-Host "[$Name] 注意: 文件模式下需要用 sync.ps1 同步变更" -ForegroundColor Yellow
} else {
    # 文件夹：用 Junction
    if (-not $realSource.StartsWith($configPath, [StringComparison]::OrdinalIgnoreCase)) {
        Move-Item -Path $realSource -Destination $Target -Force
        Write-Host "[$Name] 移动: $realSource -> $Target" -ForegroundColor Green
    }
    if (Test-Path $Source) { Remove-Item $Source -Force -Recurse }
    $parent = Split-Path $Source -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    New-Item -ItemType Junction -Path $Source -Target $Target | Out-Null
    Write-Host "[$Name] Junction: $Source -> $Target" -ForegroundColor Green
}

$manifest.packages | Add-Member -NotePropertyName $Name -NotePropertyValue @{
    target = $Target.Replace($Root, '.').Replace('\', '/')
    link   = $Source
    type   = if ($isFile) { "file" } else { "dir" }
} -Force

$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "[$Name] 已写入 manifest" -ForegroundColor Green
