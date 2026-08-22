# ============================================================
# install-hap.ps1 — 用 hdc 把(已签名)HAP 安装到手机
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath output\clashbox-signed.hap
#   powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath xxx.hap -Replace
#
# 自动检查: 手机是否连接 / HAP 最低 API 与手机系统 API 是否兼容
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
$device = Get-DeviceInfo
if (-not $device) {
    Write-Host "[错误] 未检测到设备。请：手机开启开发者模式 + USB调试/无线调试，并确认 hdc 能连上。"
    exit 1
}
$osInfo = if ($device.OsVersion) { "HarmonyOS $($device.OsVersion)" } else { 'HarmonyOS' }
$apiInfo = if ($device.ApiVersion) { "API $($device.ApiVersion)" } else { 'API 未知' }
Write-Host "设备: $($device.Serial) / $osInfo / $apiInfo"

# HAP 最低系统要求 vs 手机 API 版本
try {
    $module = Read-HapModule $hapPath
    $minApi = [int]$module.app.'minAPIVersion'
    $needApi = Get-CompatibleVersion $minApi
    Write-Host "HAP : $($module.app.'bundleName') v$($module.app.'versionName') / 需要 API $needApi 及以上"
    if ($device.ApiVersion -and ($needApi -gt [int]$device.ApiVersion)) {
        Write-Host ""
        Write-Host "[错误] 该 HAP 需要 API $needApi 及以上，但手机系统是 API $($device.ApiVersion)。"
        Write-Host "       请在 API $needApi 及以上的 HarmonyOS NEXT 设备上安装(见 README「兼容性说明」)。"
        exit 1
    }
} catch {
    Write-Host "[警告] 无法解析 HAP 的 module.json，跳过版本兼容检查。"
}

Write-Host ""
Write-Host "=== hdc install $hapPath ==="
if ($Replace) { & $script:HdcExe 'install' '-r' $hapPath 2>&1 | Out-String } else { & $script:HdcExe 'install' $hapPath 2>&1 | Out-String }
if ($LASTEXITCODE -eq 0) {
    Write-Host "[完成] 安装成功。"
} else {
    Write-Host "[错误] 安装失败(退出码 $LASTEXITCODE)。常见原因见 README 排错表。"
    exit 1
}
