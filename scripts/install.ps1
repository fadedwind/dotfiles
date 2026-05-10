# install.ps1 — 一键部署所有 symlink
# 用法: .\install.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
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

    if (-not (Test-Path $target)) {
        Write-Host "[$name] 配置文件不存在: $target — 跳过" -ForegroundColor Yellow
        continue
    }

    if (Test-Path $link) {
        $item = Get-Item $link
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $existingTarget = $item.Target
            if (-not [System.IO.Path]::IsPathRooted($existingTarget)) {
                $existingTarget = Join-Path (Split-Path $link -Parent) $existingTarget
            }
            if ($existingTarget -eq $target -or $item.FullName -eq $target) {
                Write-Host "[$name] symlink 已正确指向，跳过" -ForegroundColor Cyan
                continue
            }
        }
        Write-Host "[$name] 目标已存在（非 symlink），跳过。手动处理: $link" -ForegroundColor Yellow
        continue
    }

    # 确保父目录存在
    $parent = Split-Path $link -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $link -Target $target | Out-Null
    Write-Host "[$name] 已创建 symlink: $link -> $target" -ForegroundColor Green
}

Write-Host "`n部署完成 ✨" -ForegroundColor Green
