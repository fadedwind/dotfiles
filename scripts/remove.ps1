# remove.ps1 — 移除 symlink 并还原文件
# 用法: .\remove.ps1 <名称> [-delete]  (加 -delete 会删除配置文件而不还原)

param(
    [Parameter(Mandatory=$true)][string]$Name,
    [switch]$Delete
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ManifestPath = Join-Path $Root "manifest.json"

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

if ($manifest.packages.PSObject.Properties.Name -notcontains $Name) {
    Write-Host "[$Name] 不在 manifest 中" -ForegroundColor Red
    exit
}

$pkg = $manifest.packages.$Name
$target = Join-Path $Root ($pkg.target -replace '^\./', '')
$link = $pkg.link

# 删除 symlink
if (Test-Path $link) {
    Remove-Item $link -Force -Recurse
    Write-Host "[$Name] 已删除 symlink: $link" -ForegroundColor Yellow
}

if ($Delete) {
    # 删除配置文件
    if (Test-Path $target) {
        Remove-Item $target -Force -Recurse
        Write-Host "[$Name] 已删除配置: $target" -ForegroundColor Red
    }
} else {
    # 还原：把文件移回原位
    if (Test-Path $target) {
        $parent = Split-Path $link -Parent
        if (-not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Move-Item -Path $target -Destination $link -Force
        Write-Host "[$Name] 已还原: $target -> $link" -ForegroundColor Green
    }
}

# 从 manifest 移除
$manifest.packets.PSObject.Properties.Remove($Name) 2>$null
$manifest.packages.PSObject.Properties.Remove($Name)
$manifest | ConvertTo-Json -Depth 5 | Set-Content $ManifestPath -Encoding UTF8
Write-Host "[$Name] 已从 manifest 移除" -ForegroundColor Yellow
