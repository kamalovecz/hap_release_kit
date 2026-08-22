# ============================================================
# download-clash.ps1 — 下载最新的 ClashBox / ClashNext 未签名 HAP
# 到 input\ 目录，供本套件签名安装。
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\download-clash.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\download-clash.ps1 -Repo xiaobaigroup/ClashBox
#
# 下载来源优先级:
#   1) GitHub Releases (xiaobaigroup/ClashBox 及 org 内 clash 相关仓库)
#   2) HarmonyOS-Haps 合集仓库 README 中 clash 相关 .hap 直链
#   3) 手动放入 input\ 目录(本机无外网时的兜底)
# ============================================================
param([string]$Repo = '')

$inputDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'input'
New-Item -ItemType Directory -Path $inputDir -Force | Out-Null
$ProgressPreference = 'SilentlyContinue'
$headers = @{ 'User-Agent' = 'hap-release-kit' }

function Save-Asset($asset, $fallbackName) {
    $name = $asset.name
    $dest = Join-Path $inputDir $name
    if (Test-Path $dest) { Write-Host "  已存在，跳过: $name"; return $dest }
    Write-Host "  下载 $($asset.size) bytes <- $($asset.browser_download_url)"
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -Headers $headers -TimeoutSec 120
        Write-Host "  已保存: $dest"
        return $dest
    } catch {
        Write-Host "  下载失败: $($_.Exception.Message)"
        Remove-Item $dest -Force -ErrorAction SilentlyContinue
        return $null
    }
}

function Try-GithubRepo([string]$fullRepo) {
    Write-Host "== 尝试 GitHub 仓库: $fullRepo =="
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$fullRepo/releases/latest" -Headers $headers -TimeoutSec 30
        $assets = @($rel.assets | Where-Object { $_.name -match '\.hap$' })
        if ($assets.Count -eq 0) {
            Write-Host "  该仓库最新版本没有 .hap 资产。可用资产: $(@($rel.assets.name) -join ', ')"
            return
        }
        $pick = @($assets | Where-Object { $_.name -match 'unsigned' }) + @($assets)
        foreach ($a in ($pick | Select-Object -Unique -First 5)) {
            Save-Asset $a ($a.name)
        }
    } catch {
        Write-Host "  访问失败(可能网络受限): $($_.Exception.Message)"
    }
}

# 1) 指定仓库 或 默认 ClashBox 仓库
if ($Repo) {
    Try-GithubRepo $Repo
} else {
    Try-GithubRepo 'xiaobaigroup/ClashBox'
    # 顺便探测 xiaobaigroup 组织下有没有 clashnext 之类的仓库
    Write-Host "== 探测 xiaobaigroup 组织下的 clash 相关仓库 =="
    try {
        $orgs = @(Invoke-RestMethod -Uri 'https://api.github.com/orgs/xiaobaigroup/repos?per_page=100' -Headers $headers -TimeoutSec 30)
        $clashRepos = @($orgs | Where-Object { $_.name -match '(?i)clash' })
        foreach ($r in $clashRepos) {
            Write-Host "  发现: $($r.full_name)  (fork=$($r.fork))"
            if (-not $r.fork) { Try-GithubRepo $r.full_name }
        }
        if ($clashRepos.Count -eq 0) { Write-Host "  (未发现其它 clash 仓库)" }
    } catch {
        Write-Host "  探测失败: $($_.Exception.Message)"
    }
}

# 2) HarmonyOS-Haps 合集直链兜底
Write-Host "== 尝试 HarmonyOS-Haps 合集里的 clash 直链 =="
try {
    $readme = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Zitann/HarmonyOS-Haps/main/README.md' -Headers $headers -TimeoutSec 30
    $m = [regex]::Matches($readme.Content, 'https?://[^\s\)\]>]+\.hap')
    $links = @($m | ForEach-Object { $_.Value } | Where-Object { $_ -match '(?i)clash' } | Select-Object -Unique)
    foreach ($u in $links) {
        $name = [System.IO.Path]::GetFileName(($u -split '\?')[0])
        $dest = Join-Path $inputDir $name
        if (Test-Path $dest) { continue }
        Write-Host "  下载 $name <- $u"
        try {
            Invoke-WebRequest -Uri $u -OutFile $dest -Headers $headers -TimeoutSec 120
            Write-Host "  已保存: $dest"
        } catch { Write-Host "  下载失败: $($_.Exception.Message)" }
    }
    if ($links.Count -eq 0) { Write-Host "  (README 中没有找到 clash 相关 .hap 直链)" }
} catch {
    Write-Host "  访问失败: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "== 完成 =="
$in = Get-ChildItem $inputDir -Filter '*.hap' -ErrorAction SilentlyContinue
if ($in) {
    Write-Host "input\ 目录现有 HAP:"
    $in | ForEach-Object { Write-Host "  - $($_.Name) ($([math]::Round($_.Length/1MB,1)) MB)" }
    Write-Host ""
    Write-Host "下一步:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\<文件名> -Install"
} else {
    Write-Host "没有下载到任何 HAP。请手动把未签名 HAP 放到 input\ 目录，或检查网络后重试。"
}
