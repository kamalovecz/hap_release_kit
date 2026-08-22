# ============================================================
# refresh-profile.ps1 — 处理 Profile 缺失/过期
#
# Profile(.p7b)只能由华为云服务签名(链: HOS Profile Management Debug
# <- Huawei CBG Software Signing Service CA <- Huawei CBG Root CA G2)，
# 本机无法伪造。本脚本负责:
#   1) 展示 profiles\ 与小白调试助手 store 目录里该应用的 Profile 状态
#   2) 若工具侧已生成新 Profile，自动复制到 profiles\
#   3) 若都没有，给出在工具里重新生成的步骤
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -BundleName org.xbstudio.clashnext
#   powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -ProfilePath 某个.p7b   (手动导入)
# ============================================================
param(
    [string]$BundleName,
    [string]$ProfilePath
)

. (Join-Path $PSScriptRoot 'lib-common.ps1')

$kitProfiles = Get-KitPath 'profiles'
New-Item -ItemType Directory -Path $kitProfiles -Force | Out-Null

if ($ProfilePath) {
    if (-not (Test-Path $ProfilePath)) { Write-Host "[错误] 文件不存在: $ProfilePath"; exit 1 }
    Copy-Item $ProfilePath (Join-Path $kitProfiles (Split-Path -Leaf $ProfilePath)) -Force
    Write-Host "[完成] 已导入: $ProfilePath"
    exit 0
}

if (-not $BundleName) {
    Write-Host "[错误] 需要 -BundleName 或 -ProfilePath 参数"
    exit 1
}

Write-Host "=== 检查 $BundleName 的 Profile ==="

# 工具默认 store 目录(小白调试助手生成的 Profile 都在这)
$toolStore = Join-Path $env:USERPROFILE 'Documents\hap_installer\store'
Write-Host "工具 store 目录: $toolStore"

$allCandidates = @()
Get-ChildItem $kitProfiles -Filter '*.p7b' -ErrorAction SilentlyContinue | ForEach-Object { $allCandidates += $_.FullName }
if (Test-Path $toolStore) {
    Get-ChildItem $toolStore -Filter '*.p7b' -ErrorAction SilentlyContinue | ForEach-Object { $allCandidates += $_.FullName }
}
$allCandidates = $allCandidates | Select-Object -Unique

$found = @()
foreach ($f in $allCandidates) {
    try {
        $info = Read-ProfileInfo $f
        if ($info.BundleName -eq $BundleName) {
            $valid = Test-ProfileValid $info
            $exp = if ($valid) { '有效' } else { '已过期' }
            Write-Host ("  {0}  [{1}]  有效期至 {2}" -f $f, $exp, [DateTimeOffset]::FromUnixTimeSeconds($info.NotAfter).LocalDateTime)
            $found += [PSCustomObject]@{ Info = $info; Valid = $valid }
        }
    } catch {}
}

$validOne = $found | Where-Object { $_.Valid } | Sort-Object { $_.Info.NotAfter } -Descending | Select-Object -First 1
if ($validOne) {
    $dest = Join-Path $kitProfiles (Split-Path -Leaf $validOne.Info.File)
    Copy-Item $validOne.Info.File $dest -Force
    Write-Host ""
    Write-Host "[完成] 已同步有效 Profile 到套件: $dest"
    Write-Host "       bundle=$($validOne.Info.BundleName) / 设备=$($validOne.Info.DeviceIds -join ',')"
    exit 0
}

Write-Host ""
Write-Host "[提示] 没有找到 $BundleName 的有效 Profile。需要先让小白调试助手重新生成："
Write-Host "  1) 把该应用的未签名 HAP 拖进小白调试助手(会加入应用列表)；"
Write-Host "  2) 手机连好后，点「更多 → 重置证书和Profile」(工具会调用华为云为列表中的应用重新生成 Profile)；"
Write-Host "  3) 重新运行本脚本(会自动从 store 目录同步到套件)："
Write-Host "       powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -BundleName $BundleName"
Write-Host ""
Write-Host "  备选: 也可以直接指定工具刚生成的 p7b 文件导入："
Write-Host "       powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -ProfilePath <新生成的.p7b>"
exit 1
