# ============================================================
# sign-hap.ps1 — 用本地 signer.exe 签名 HAP(绕过工具坏掉的 50424 流程)
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\sign-hap.ps1 `
#       -HapPath input\clashbox_unsigned.hap `
#       -ProfilePath profiles\org_xbgroup_clashboxLTS.p7b `
#       -OutPath output\clashbox-signed.hap
#
# 可选参数:
#   -SignCode <0|1>            默认自动: HAP 含原生 .so 则为 1
#   -CompatibleVersion <int>   默认由 module.json 的 minAPIVersion 推导
# ============================================================
param(
    [Parameter(Mandatory=$true)][string]$HapPath,
    [Parameter(Mandatory=$true)][string]$ProfilePath,
    [Parameter(Mandatory=$true)][string]$OutPath,
    [int]$SignCode = -1,
    [int]$CompatibleVersion = -1
)

. (Join-Path $PSScriptRoot 'lib-common.ps1')

$hapPath = $HapPath
if (-not [System.IO.Path]::IsPathRooted($hapPath)) { $hapPath = Join-Path (Get-KitPath '') $hapPath }
$profilePath = $ProfilePath
if (-not [System.IO.Path]::IsPathRooted($profilePath)) { $profilePath = Join-Path (Get-KitPath '') $profilePath }
$outPath = $OutPath
if (-not [System.IO.Path]::IsPathRooted($outPath)) { $outPath = Join-Path (Get-KitPath '') $outPath }

if (-not (Test-Path $hapPath))     { Write-Host "[错误] 未找到 HAP: $hapPath"; exit 1 }
if (-not (Test-Path $profilePath)) { Write-Host "[错误] 未找到 Profile: $profilePath"; exit 1 }

$outDir = Split-Path -Parent $outPath
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

Write-Host "=== 解析 HAP: $hapPath ==="
$module = Read-HapModule $hapPath
$bundle  = $module.app.'bundleName'
$minApi  = [int]$module.app.'minAPIVersion'
$version = $module.app.'versionName'
Write-Host "  bundleName=$bundle  version=$version  minAPIVersion=$minApi"

if ($CompatibleVersion -lt 0) { $CompatibleVersion = Get-CompatibleVersion $minApi }
if ($SignCode -lt 0) {
    $hasLibs = Test-HapHasNativeLibs $hapPath
    $SignCode = if ($hasLibs) { 1 } else { 0 }
    Write-Host "  原生库: $hasLibs => signCode=$SignCode"
}
Write-Host "  compatibleVersion=$CompatibleVersion"

Write-Host "=== 检查 Profile: $profilePath ==="
$info = Read-ProfileInfo $profilePath
if ($info.BundleName -ne $bundle) {
    Write-Host "[错误] Profile 包名($($info.BundleName)) 与 HAP 包名($bundle) 不一致！"
    exit 1
}
if (-not (Test-ProfileValid $info)) {
    Write-Host "[错误] Profile 已过期(有效期至 $([DateTimeOffset]::FromUnixTimeSeconds($info.NotAfter).LocalDateTime))。"
    Write-Host "       请先用小白调试助手为 $bundle 重新生成 Profile(见 README「Profile 过期怎么办」)。"
    exit 1
}
Write-Host "  Profile OK: $bundle / debug / 有效期至 $([DateTimeOffset]::FromUnixTimeSeconds($info.NotAfter).LocalDateTime)"

Write-Host "=== 调用 signer.exe 签名 ==="
$result = Invoke-Signer @(
    'sign-app', '-mode', 'localSign',
    '-keyAlias', $script:KeyAlias,
    '-appCertFile',  $script:AppCert,
    '-profileFile',  $profilePath,
    '-signAlg', 'SHA256withECDSA',
    '-keystoreFile', $script:KeyPem,
    '-keystorePwd',  $script:KeyPwd,
    '-inFile', $hapPath,
    '-outFile', $outPath,
    '-compatibleVersion', "$CompatibleVersion",
    '-signCode', "$SignCode"
)
$exitCode = $result[0]; $output = $result[1]
Write-Host $output

if ($output -notmatch 'sign-app success' -or -not (Test-Path $outPath)) {
    Write-Host "[错误] 签名失败。常见原因见 README 排错表。"
    exit 1
}

Write-Host "=== 校验签名 (verify-app) ==="
$vOut = 'output\_verify_tmp'
$chain = Join-Path (Get-KitPath '') "$vOut\chain.cer"
$prof  = Join-Path (Get-KitPath '') "$vOut\profile.p7b"
$vdir = Split-Path -Parent $chain
if (-not (Test-Path $vdir)) { New-Item -ItemType Directory -Path $vdir -Force | Out-Null }
$vResult = Invoke-Signer @('verify-app', '-inFile', $outPath, '-outCertChain', $chain, '-outProfile', $prof)
if ($vResult[1] -match 'verify-app success') {
    Write-Host "[完成] 签名校验通过: $outPath  ($([math]::Round((Get-Item $outPath).Length/1MB,1)) MB)"
    Remove-Item $vdir -Recurse -Force -ErrorAction SilentlyContinue
    exit 0
} else {
    Write-Host $vResult[1]
    Write-Host "[警告] 签名已生成但校验未通过，请检查 Profile 与证书是否匹配。"
    exit 2
}
