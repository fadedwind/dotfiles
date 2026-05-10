# sync.ps1 — 双向同步文件类型的配置
# 用法: .\sync.ps1          (全部同步)
#       .\sync.ps1 <名称>    (同步单个)
# 逻辑: 比较修改时间，新的覆盖旧的

param([string]$Name)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Root = Split-Path -Parent $ScriptDir
$ManifestPath = Join-Path $Root "manifest.json"

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json

$names = if ($Name) { @($Name) } else { @($manifest.packages.PSObject.Properties.Name) }

foreach ($n in $names) {
    $pkg = $manifest.packages.$n
    if ($pkg.type -ne "file") { continue }

    $target = Join-Path $Root ($pkg.target -replace '^\./', '')
    $link = $pkg.link

    if (-not (Test-Path $target) -or -not (Test-Path $link)) {
        Write-Host "[$n] 文件缺失，跳过" -ForegroundColor Yellow
        continue
    }

    $srcTime = (Get-Item $link).LastWriteTime
    $cfgTime = (Get-Item $target).LastWriteTime

    if ($srcTime -gt $cfgTime) {
        Copy-Item -Path $link -Destination $target -Force
        Write-Host "[$n] 原文件更新 -> 已同步到 config ($($srcTime.ToString('HH:mm:ss')))" -ForegroundColor Green
    } elseif ($cfgTime -gt $srcTime) {
        Copy-Item -Path $target -Destination $link -Force
        Write-Host "[$n] config 更新 -> 已同步到原位 ($($cfgTime.ToString('HH:mm:ss')))" -ForegroundColor Cyan
    } else {
        Write-Host "[$n] 已是最新" -ForegroundColor DarkGray
    }
}
