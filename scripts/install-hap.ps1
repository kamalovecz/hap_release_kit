# ============================================================
# install-hap.ps1 — 用 hdc 把(已签名)HAP 安装到手机
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath output\clashbox-signed.hap
#   powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath xxx.hap -Replace
# ============================================================
param(
    [Parameter(Mandatory=$true)][string]$HapPath,
    [switch]$Replace
)

. (Join-Path $PSScriptRoot 'lib-common.ps1')

$hapPath = $HapPath
if (-not [System.IO.Path]::IsPathRooted($hapPath)) { $hapPath = Join-Path (Get-KitPath '') $hapPath }
if (-not (Test-Path $hapPath)) { Write-Host "[错误] 未找到 HAP: $hapPath"; exit 1 }

Write-Host "=== 检查设备 ==="
$targets = & $script:HdcExe 'list' 'targets' 2>&1 | Out-String
Write-Host $targets
if ($targets -notmatch '\S' -or ($targets -match 'Empty')) {
    Write-Host "[错误] 未检测到设备。请：手机开启开发者模式 + USB调试/无线调试，并确认 hdc 能连上。"
    exit 1
}

Write-Host "=== hdc install $hapPath ==="
if ($Replace) { & $script:HdcExe 'install' '-r' $hapPath 2>&1 | Out-String } else { & $script:HdcExe 'install' $hapPath 2>&1 | Out-String }
if ($LASTEXITCODE -eq 0) {
    Write-Host "[完成] 安装成功。"
} else {
    Write-Host "[错误] 安装失败(退出码 $LASTEXITCODE)。常见原因见 README 排错表。"
    exit 1
}
