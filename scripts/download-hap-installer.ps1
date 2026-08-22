# ============================================================
# download-hap-installer.ps1 — 从作者仓库下载「小白调试助手」(auto-installer)
#
# 仓库: https://github.com/likuai2010/auto-installer
# 默认下载最新 Windows 版并解压到 ext\hap_installer\
# 下载后自动尝试把工具生成的 key.pem 同步到套件 certs\(签名必需)
#
# 用法:
#   powershell -ExecutionPolicy Bypass -File scripts\download-hap-installer.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\download-hap-installer.ps1 -NoExtract
# ============================================================
param([switch]$NoExtract)

$ProgressPreference = 'SilentlyContinue'
$headers = @{ 'User-Agent' = 'hap-release-kit' }
$kitRoot = Split-Path -Parent $PSScriptRoot
$extDir  = Join-Path $kitRoot 'ext'

Write-Host "=============================================="
Write-Host " 小白调试助手 (auto-installer) 下载器"
Write-Host " 来源仓库: github.com/likuai2010/auto-installer"
Write-Host "=============================================="

# 1) 查询最新 Release
Write-Host "== 查询最新版本 =="
$rel = $null
try {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/likuai2010/auto-installer/releases/latest' -Headers $headers -TimeoutSec 30
} catch {
    Write-Host "[错误] 无法访问 GitHub API: $($_.Exception.Message)"
    Write-Host "       请手动下载 Windows 版:"
    Write-Host "       https://github.com/likuai2010/auto-installer/releases"
    Write-Host "       (或官网 https://www.sydxky.cn/xiaobai.php)"
    exit 1
}
$winAsset = @($rel.assets | Where-Object { $_.name -match 'Windows.*\.zip$' }) | Select-Object -First 1
if (-not $winAsset) {
    Write-Host "[错误] 最新版本($($rel.tag_name))没有 Windows 资产。可用: $(@($rel.assets.name) -join ', ')"
    exit 1
}
Write-Host "版本: $($rel.tag_name)  发布时间: $($rel.published_at)"

# 2) 下载
New-Item -ItemType Directory -Path $extDir -Force | Out-Null
$zipPath = Join-Path $extDir $winAsset.name
if (Test-Path $zipPath) {
    Write-Host "已存在，跳过下载: $zipPath"
} else {
    Write-Host "下载 $($winAsset.name)  ($([math]::Round($winAsset.size/1MB,1)) MB)"
    try {
        Invoke-WebRequest -Uri $winAsset.browser_download_url -OutFile $zipPath -Headers $headers -TimeoutSec 300
        Write-Host "已保存: $zipPath"
    } catch {
        Write-Host "[错误] 下载失败: $($_.Exception.Message)"
        Write-Host "       国内网络受限时请手动下载(见上方链接)后放到 $extDir"
        exit 1
    }
}

# 3) 解压
$toolDir = Join-Path $extDir 'hap_installer'
if (-not $NoExtract) {
    if (-not (Test-Path (Join-Path $toolDir 'Release\hap_installer.exe'))) {
        Write-Host "== 解压到 $toolDir =="
        Expand-Archive -Path $zipPath -DestinationPath $toolDir -Force
    } else {
        Write-Host "已解压，跳过: $toolDir"
    }
    $exe = Join-Path $toolDir 'Release\hap_installer.exe'
    if (Test-Path $exe) { Write-Host "工具就绪: $exe" }
}

# 4) 自动同步 key.pem 到套件 certs\(签名必需)
Write-Host "== 同步 key.pem 到 certs\ =="
$toolStore = Join-Path $env:USERPROFILE 'Documents\hap_installer\store\key.pem'
$kitCerts  = Join-Path $kitRoot 'certs'
New-Item -ItemType Directory -Path $kitCerts -Force | Out-Null
if (Test-Path $toolStore) {
    Copy-Item $toolStore (Join-Path $kitCerts 'key.pem') -Force
    Write-Host "已从工具 store 复制 key.pem: $toolStore"
} else {
    Write-Host "[提示] 还没找到工具的 store\key.pem。"
    Write-Host "       请先运行一次小白调试助手并完成「重置证书和Profile」, 再重跑本脚本。"
    Write-Host "       或者手动复制: C:\Users\<你>\Documents\hap_installer\store\key.pem -> certs\key.pem"
}

Write-Host ""
Write-Host "== 下一步 =="
Write-Host "1) 运行工具: ext\hap_installer\Release\hap_installer.exe"
Write-Host "2) 手机开启开发者模式+USB调试并连接, 工具内登录华为账号"
Write-Host "3) 把未签名 HAP 拖进工具, 点「更多→重置证书和Profile」生成你的设备 Profile"
Write-Host "4) 回到本套件: scripts\refresh-profile.ps1 -BundleName <包名>"
Write-Host "5) 一键签名安装: scripts\build-hap.ps1 -HapPath input\<未签名.hap> -Install"
Write-Host ""
Write-Host "详细步骤见 README.md「完整使用教程」"
