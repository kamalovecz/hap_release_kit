# ============================================================
# hap_release_kit 公共函数库
# 本文件被其它脚本点用(Import-Module 或 dot-source)，不直接执行
# ============================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# 套件根目录(本文件位于 <root>\scripts 下)
$script:KitRoot = Split-Path -Parent $PSScriptRoot

function Get-KitPath([string]$relative) { return (Join-Path $script:KitRoot $relative) }

# signer.exe / hdc.exe 路径
$script:SignerExe = Get-KitPath 'tools\signer.exe'
$script:HdcExe    = Get-KitPath 'tools\hdc.exe'
# 默认证书材料(复制自小白调试助手的 store 目录)
$script:AppCert   = Get-KitPath 'certs\xiaobai-debug.cer'
$script:KeyPem    = Get-KitPath 'certs\key.pem'
$script:KeyPwd    = 'xiaobai123'
$script:KeyAlias  = 'xiaobai'

# ------------------------------------------------------------
# 读取 HAP 内的 module.json(app 段)，返回对象
# ------------------------------------------------------------
function Read-HapModule([string]$hapPath) {
    if (-not (Test-Path $hapPath)) { throw "HAP 不存在: $hapPath" }
    $zip = [System.IO.Compression.ZipFile]::OpenRead($hapPath)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -match 'module.json$' } | Select-Object -First 1
        if (-not $entry) { throw "HAP 中没有 module.json: $hapPath" }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $json = $reader.ReadToEnd(); $reader.Close()
        $obj = $json | ConvertFrom-Json
        return $obj
    } finally { $zip.Dispose() }
}

# ------------------------------------------------------------
# 判断 HAP 是否含原生 .so(决定是否需要代码签名 signCode=1)
# ------------------------------------------------------------
function Test-HapHasNativeLibs([string]$hapPath) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($hapPath)
    try {
        return [bool]($zip.Entries | Where-Object { $_.FullName -match 'libs/.*\.so$' } | Select-Object -First 1)
    } finally { $zip.Dispose() }
}

# ------------------------------------------------------------
# 由 minAPIVersion 推导 signer 的 compatibleVersion 参数
#   50000012 -> 12 ; 50005017 -> 17 ; 50100018 -> 18 ; 60000020 -> 20 ; 9 -> 9
# ------------------------------------------------------------
function Get-CompatibleVersion([int]$minApiVersion) {
    if ($minApiVersion -ge 50000000) {
        $v = ($minApiVersion - 50000000) % 100
        if ($v -lt 8) { $v = 8 }   # 兜底
        return $v
    }
    return $minApiVersion
}

# ------------------------------------------------------------
# 解析签名后的 Profile(.p7b)，取出内嵌 JSON 的关键字段
# 返回: bundleName / notBefore / notAfter / type / uuid
# ------------------------------------------------------------
function Read-ProfileInfo([string]$profilePath) {
    if (-not (Test-Path $profilePath)) { throw "Profile 不存在: $profilePath" }
    $bytes = [System.IO.File]::ReadAllBytes($profilePath)
    $text  = [System.Text.Encoding]::ASCII.GetString($bytes)
    $start = $text.IndexOf('{"version-name"')
    if ($start -lt 0) { $start = $text.IndexOf('{') }
    if ($start -lt 0) { throw "无法解析 p7b: $profilePath" }
    # JSON 到匹配的右括号(简单扫描，p7b 内 JSON 无嵌套转义问题)
    $depth = 0; $end = -1
    for ($i = $start; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($c -eq '{') { $depth++ } elseif ($c -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
    }
    if ($end -lt 0) { throw "p7b 内 JSON 不完整: $profilePath" }
    $json = $text.Substring($start, $end - $start + 1) | ConvertFrom-Json
    $info = [PSCustomObject]@{
        BundleName = $json.'bundle-info'.'bundle-name'
        Type       = $json.type
        Uuid       = $json.uuid
        NotBefore  = $json.validity.'not-before'
        NotAfter   = $json.validity.'not-after'
        DeviceIds  = @($json.'debug-info'.'device-ids')
        File       = $profilePath
    }
    return $info
}

# ------------------------------------------------------------
# Profile 是否在有效期内
# ------------------------------------------------------------
function Test-ProfileValid($profileInfo) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    return ($profileInfo.NotAfter -gt $now) -and ($profileInfo.NotBefore -le $now)
}

# ------------------------------------------------------------
# 在 profiles 目录里按 bundleName 找最合适的 p7b(有效期内优先)
# 返回 ProfileInfo 或 $null
# ------------------------------------------------------------
function Find-ProfileForBundle([string]$bundleName) {
    $dir = Get-KitPath 'profiles'
    $files = Get-ChildItem $dir -Filter '*.p7b' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        try {
            $info = Read-ProfileInfo $f.FullName
            if ($info.BundleName -eq $bundleName) {
                if (Test-ProfileValid $info) { return $info }
                Write-Host "[警告] Profile 已过期($($f.Name)): $([DateTimeOffset]::FromUnixTimeSeconds($info.NotAfter).LocalDateTime)"
            }
        } catch { Write-Host "[警告] 解析失败: $($f.Name) => $($_.Exception.Message)" }
    }
    return $null
}

# ------------------------------------------------------------
# 探测已连接设备(HarmonyOS 版本 / API 版本)
# 返回 PSCustomObject {Serial, ApiVersion, OsVersion}；无设备返回 $null
# ------------------------------------------------------------
function Get-DeviceInfo {
    try {
        $targets = (& $script:HdcExe 'list' 'targets' 2>$null | Out-String).Trim()
        if (-not $targets -or $targets -match 'Empty') { return $null }
        $serial = ($targets -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -First 1).Trim()
        $api = (& $script:HdcExe 'shell' 'param' 'get' 'const.product.ohos.apiversion' 2>$null | Out-String).Trim()
        $osv = (& $script:HdcExe 'shell' 'param' 'get' 'const.product.ohos.version' 2>$null | Out-String).Trim()
        return [PSCustomObject]@{ Serial = $serial; ApiVersion = $api; OsVersion = $osv }
    } catch { return $null }
}

# ------------------------------------------------------------
# 调用 signer.exe 并返回 (退出码, 输出文本)
# 注意：参数名不能用 $args(与 PowerShell 自动变量冲突)
# ------------------------------------------------------------
function Invoke-Signer([string[]]$Arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:SignerExe
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    # PS 5.1 兼容：手工拼接命令行参数(仅当含空格时加引号；路径含反斜杠无需引号)
    $sb = New-Object System.Text.StringBuilder
    foreach ($a in $Arguments) {
        if ($a -match '\s') {
            [void]$sb.Append('"')
            [void]$sb.Append($a)
            [void]$sb.Append('"')
        } else {
            [void]$sb.Append($a)
        }
        [void]$sb.Append(' ')
    }
    $psi.Arguments = $sb.ToString().TrimEnd()
    $p = [System.Diagnostics.Process]::Start($psi)
    # 必须异步同时读 stdout/stderr，否则管道缓冲区填满会死锁
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(120000)) {
        try { $p.Kill() } catch {}
        return @(-1, "signer.exe 执行超时，已终止")
    }
    $out = $outTask.Result
    $err = $errTask.Result
    return @($p.ExitCode, "$out`n$err")
}
