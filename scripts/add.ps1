# add.ps1 — 把一个配置文件夹加入包管理器
# 用法: .\add.ps1 <名称> <原始路径>

param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Source
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
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

# 如果原始路径是 symlink，解析到真实路径
$realSource = $Source
if ((Get-Item $Source).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $realSource = (Get-Item $Source).Target
    if (-not [System.IO.Path]::IsPathRooted($realSource)) {
        $realSource = Join-Path (Split-Path $Source -Parent) $realSource
    }
    Write-Host "[$Name] 原路径是 symlink，解析到: $realSource" -ForegroundColor Cyan
}

# 如果源已经被管理（在 config 目录内），直接注册
$configPath = (Get-Item $ConfigDir).FullName
if ($realSource.StartsWith($configPath, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Host "[$Name] 文件已在 config/ 中，直接注册" -ForegroundColor Cyan
}
else {
    # 移动文件到 config 目录
    Move-Item -Path $realSource -Destination $Target -Force
    Write-Host "[$Name] 已移动: $realSource -> $Target" -ForegroundColor Green
}

# 在原位创建 symlink
if (Test-Path $Source) {
    Remove-Item $Source -Force -Recurse
}
New-Item -ItemType SymbolicLink -Path $Source -Target $Target | Out-Null
Write-Host "[$Name] 已创建 symlink: $Source -> $Target" -ForegroundColor Green

# 更新 manifest
$manifest.packages | Add-Member -NotePropertyName $Name -NotePropertyValue @{
    target = $Target.Replace($Root, '.')
    link   = $Source
} -Force

$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "[$Name] 已写入 manifest.json" -ForegroundColor Green
