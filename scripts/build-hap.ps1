# ============================================================
# build-hap.ps1 — 一键构建：自动匹配 Profile → 签名 → 校验 → (可选)安装
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\clashbox_unsigned.hap
#   powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\clashbox_unsigned.hap -Install
#   powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath xxx.hap -Install -Replace
#
# 无 -HapPath 时自动选取 input\ 下第一个 .hap
# ============================================================
param(
    [string]$HapPath,
    [switch]$Install,
    [switch]$Replace
)

. (Join-Path $PSScriptRoot 'lib-common.ps1')

if (-not $HapPath) {
    $first = Get-ChildItem (Get-KitPath 'input') -Filter '*.hap' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $first) { Write-Host "[错误] input\ 下没有 .hap 文件"; exit 1 }
    $HapPath = $first.FullName
}
$hapPath = $HapPath
if (-not [System.IO.Path]::IsPathRooted($hapPath)) { $hapPath = Join-Path (Get-KitPath '') $hapPath }
if (-not (Test-Path $hapPath)) { Write-Host "[错误] 未找到 HAP: $hapPath"; exit 1 }

$module = Read-HapModule $hapPath
$bundle = $module.app.'bundleName'
$version = $module.app.'versionName'
Write-Host "=================================================="
Write-Host " 目标: $bundle  v$version"
Write-Host "=================================================="

# 手机兼容性提示(仅提示；签名本身不依赖手机在线)
$needApi = Get-CompatibleVersion ([int]$module.app.'minAPIVersion')
Write-Host " 该 HAP 最低需要 API $needApi (minAPIVersion=$($module.app.'minAPIVersion'))"
$device = Get-DeviceInfo
if ($device) {
    if ($device.ApiVersion) {
        $mark = if ($needApi -gt [int]$device.ApiVersion) { '⚠️ 手机系统过低' } else { '✅ 兼容' }
        Write-Host " 手机: API $($device.ApiVersion) (HarmonyOS $($device.OsVersion)) → $mark"
        if ($needApi -gt [int]$device.ApiVersion) {
            Write-Host "  [!] 该 HAP 无法安装在当前手机上(需要 API $needApi+)，安装步骤会失败。"
        }
    } else {
        Write-Host " 手机已连接，但无法读取 API 版本(跳过兼容检查)。"
    }
} else {
    Write-Host " 未检测到手机(仅签名不影响；如需安装请先连接手机并加 -Install)。"
}

# 自动匹配 Profile
$profileInfo = Find-ProfileForBundle $bundle
if (-not $profileInfo) {
    Write-Host "[错误] profiles\ 中没有 $bundle 的有效 Profile。"
    Write-Host "       请运行 scripts\refresh-profile.ps1 -BundleName $bundle 或阅读 README「Profile 过期怎么办」。"
    exit 1
}

# 输出文件名: <bundle>-signed.hap
$safe = $bundle -replace '[^a-zA-Z0-9_.-]', '_'
$outPath = Join-Path (Get-KitPath 'output') "$safe-signed.hap"

# 调用签名脚本
& (Join-Path $PSScriptRoot 'sign-hap.ps1') -HapPath $hapPath -ProfilePath $profileInfo.File -OutPath $outPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Install) {
    Write-Host ""
    Write-Host "=== 开始安装 ==="
    & (Join-Path $PSScriptRoot 'install-hap.ps1') -HapPath $outPath -Replace:$Replace
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "[全部完成] $bundle 已安装到手机。"
} else {
    Write-Host "[完成] 已生成签名包: $outPath"
    Write-Host "       加 -Install 参数可一步签名+安装。"
}
exit 0
