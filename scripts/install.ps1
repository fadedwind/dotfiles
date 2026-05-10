# install.ps1 — 一键部署所有链接
# 用法: .\install.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Root = Split-Path -Parent $ScriptDir
$ManifestPath = Join-Path $Root "manifest.json"

if (-not (Test-Path $ManifestPath)) {
    Write-Host "manifest.json 不存在" -ForegroundColor Red
    exit
}

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

foreach ($name in $manifest.packages.PSObject.Properties.Name) {
    $pkg = $manifest.packages.$name
    $target = Join-Path $Root ($pkg.target -replace '^\./', '')
    $link = $pkg.link
    $type = $pkg.type

    if (-not (Test-Path $target)) {
        Write-Host "[$name] 配置不存在: $target — 跳过" -ForegroundColor Yellow
        continue
    }

    if (Test-Path $link) {
        $item = Get-Item $link
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "[$name] 链接已存在，跳过" -ForegroundColor Cyan
            continue
        }
        Write-Host "[$name] 目标已存在且不是链接，跳过: $link" -ForegroundColor Yellow
        continue
    }

    $parent = Split-Path $link -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

    if ($type -eq "file") {
        New-Item -ItemType HardLink -Path $link -Target $target | Out-Null
    } else {
        New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    }
    Write-Host "[$name] 已链接: $link -> $target" -ForegroundColor Green
}

Write-Host "`n部署完成 ✨" -ForegroundColor Green
