# add.ps1 — 把一个配置文件/文件夹加入包管理器
# 用法: .\add.ps1 <名称> <原始路径>

param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Source
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyScript.Path)
$ConfigDir = Join-Path $Root "config"
$Target = Join-Path $ConfigDir $Name
$ManifestPath = Join-Path $Root "manifest.json"

# 读取 manifest
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

# 检查是否已存在
if ($manifest.packages.PSObject.Properties.Name -contains $Name) {
    Write-Host "[$Name] 已存在于 manifest 中，跳过" -ForegroundColor Yellow
    exit
}

# 确保 config 目录存在
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

# 标准化路径
$Source = [System.IO.Path]::GetFullPath($Source)

if (-not (Test-Path $Source)) {
    Write-Host "源路径不存在: $Source" -ForegroundColor Red
    exit
}

$item = Get-Item $Source
$isFile = -not $item.PSIsContainer

# 解析 symlink
$realSource = $Source
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $realTarget = if ($isFile) { (Get-Item $Source).Target } else { (Get-Item $Source).Target }
    if ($realTarget) {
        if (-not [System.IO.Path]::IsPathRooted($realTarget)) {
            $realSource = Join-Path (Split-Path $Source -Parent) $realTarget
        } else {
            $realSource = $realTarget
        }
        Write-Host "[$Name] 原路径是 symlink，解析到: $realSource" -ForegroundColor Cyan
    }
}

# 如果源已经在 config 目录内，跳过移动
$configPath = (Get-Item $ConfigDir).FullName
$alreadyManaged = $realSource.StartsWith($configPath, [StringComparison]::OrdinalIgnoreCase)

if ($alreadyManaged) {
    Write-Host "[$Name] 文件已在 config/ 中，直接注册" -ForegroundColor Cyan
    $Target = $realSource
} else {
    # 对于文件：目标保留文件名
    if ($isFile) {
        $Target = Join-Path $ConfigDir "$Name$($item.Extension)"
    }

    # 移动到 config 目录
    Move-Item -Path $realSource -Destination $Target -Force
    Write-Host "[$Name] 已移动: $realSource -> $Target" -ForegroundColor Green
}

# 在原位创建 symlink
if (Test-Path $Source) {
    Remove-Item $Source -Force -Recurse
}
# 确保父目录存在
$parent = Split-Path $Source -Parent
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
New-Item -ItemType SymbolicLink -Path $Source -Target $Target | Out-Null
Write-Host "[$Name] symlink: $Source -> $Target" -ForegroundColor Green

# 更新 manifest
$relTarget = $Target.Replace($Root, '.')
$manifest.packages | Add-Member -NotePropertyName $Name -NotePropertyValue @{
    target = $relTarget
    link   = $Source
} -Force

$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "[$Name] 已写入 manifest" -ForegroundColor Green
