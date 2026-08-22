# hap_release_kit — HarmonyOS HAP 签名安装套件（可复制版）

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![HarmonyOS](https://img.shields.io/badge/HarmonyOS-NEXT%205.0%2B-blueviolet)
[![Release](https://img.shields.io/github/v/release/kamalovecz/hap_release_kit)](https://github.com/kamalovecz/hap_release_kit/releases)

一套**面向新手的、从零开始的** HarmonyOS HAP 签名/安装工具集。
你只需要：一台 Windows 电脑 + 一部 HarmonyOS NEXT 手机 + 一个华为账号，
就能**下载 → 生成自己的签名 → 安装**任意 HAP（以 ClashBox LTS 为例）。

> 解决的问题：小白调试助手（hap_installer 3.1.0）的"自动签名"会报
> `127.0.0.1:50424 连接被拒绝`（死循环，详见[背景](#三为什么不能用工具的自动签名背景)）。
> 本套件改用**本机 signer.exe 直接签名 + hdc 安装**，稳定可靠，实测成功。

---

## 📦 下载（GitHub Releases）

| 文件 | 说明 | 适用 |
|---|---|---|
| [ClashBox_LTS_V1_unsigned.hap](https://github.com/kamalovecz/hap_release_kit/releases/download/v1.7.4/ClashBox_LTS_V1_unsigned.hap) | ClashBox LTS 1.7.4 **官方未签名包**（来源: [xiaobaigroup/ClashBox](https://github.com/xiaobaigroup/ClashBox) v1.7.4 Release，与设备无关） | **任何型号的 HarmonyOS NEXT 设备**，按下方教程为自己签名安装 |
| [org.xbgroup.clashboxLTS-signed.hap](https://github.com/kamalovecz/hap_release_kit/releases/download/v1.7.4/org.xbgroup.clashboxLTS-signed.hap) | 已签名安装包（作者设备的签名产物） | ⚠️ **仅绑定 Profile 里的那一台手机**，他人/其他型号无法安装 |

> 关键认知：**未签名 HAP 人人可签；Profile 一人一机**（Profile 由华为云签发并绑定你的手机 UDID）。

---

## 🚀 完整使用教程（从零开始，任何设备通用）

```mermaid
flowchart LR
    A[下载小白调试助手] --> B[连接手机+登录华为账号]
    B --> C[下载未签名 HAP]
    C --> D[工具生成你的设备 Profile]
    D --> E[克隆本套件+恢复 key.pem]
    E --> F[同步 Profile+签名]
    F --> G[hdc 安装+验证]
```

### 第 0 步 · 准备

- **电脑**：Windows 10/11（本文全部命令用 PowerShell）；
- **手机**：HarmonyOS NEXT 5.0 及以上（如何判断你的版本/API → [兼容性说明](#兼容性说明鸿蒙版本)）；
- **开启开发者模式**：手机 设置 → 关于本机 → 连续点击"版本号"7 次 → 返回设置 → 系统与更新 → 开发者选项 → 打开 **USB 调试**；
- 用 USB 线连接电脑，手机上弹出的"允许 USB 调试"选择**允许**（可勾选"始终允许"）。

### 第 1 步 · 下载小白调试助手（auto-installer）

作者仓库：[github.com/likuai2010/auto-installer](https://github.com/likuai2010/auto-installer)（当前最新 v3.1.0）

**方式 A（推荐，脚本自动下载+解压）**，在本套件目录执行：

```bat
powershell -ExecutionPolicy Bypass -File scripts\download-hap-installer.ps1
```

脚本会：查询最新版 → 下载 `hap_installer-Windows-3.1.0.zip`（约 81MB）→ 解压到 `ext\hap_installer\` →
自动把工具生成的 `key.pem` 同步到本套件 `certs\`。

**方式 B（手动）**：直接下载
[hap_installer-Windows-3.1.0.zip](https://github.com/likuai2010/auto-installer/releases/download/3.1.0/hap_installer-Windows-3.1.0.zip)
（或官网 https://www.sydxky.cn/xiaobai.php），解压后运行 `Release\hap_installer.exe`。

> 工具运行后会把签名材料写到 `C:\Users\<你>\Documents\hap_installer\store\`（后面会用到）。

### 第 2 步 · 连接手机 + 登录华为账号

1. 运行 `hap_installer.exe`，确认界面右上角显示已连接的设备（绿色/已连接状态）；
2. 点击登录，用**你的华为账号**登录（生成 Profile 必须走华为云，账号不登录无法生成）；
3. 命令行确认连接（可选）：
   ```bat
   ext\hap_installer\Release\data\flutter_assets\assets\windows\hdc.exe list targets
   ```
   能看到你的设备序列号即 OK。

### 第 3 步 · 下载未签名 HAP

- 从本套件 [Releases](#下载github-releases) 下载 `ClashBox_LTS_V1_unsigned.hap`，放到 `input\`；
- 或用脚本自动拉取最新版：
  ```bat
  powershell -ExecutionPolicy Bypass -File scripts\download-clash.ps1
  ```

### 第 4 步 · 用工具生成「你的设备专属 Profile」（关键）

Profile 决定"能不能装到你的手机"（绑定你的 UDID），必须由华为云签发：

1. 把 `input\ClashBox_LTS_V1_unsigned.hap` **拖进**小白调试助手窗口（加入应用列表）；
2. 点 **更多 → 重置证书和Profile**，等待完成；
3. 工具会为 `org.xbgroup.clashboxLTS` 生成新的 Profile：
   `C:\Users\<你>\Documents\hap_installer\store\org_xbgroup_clashboxLTS.p7b`
   （有效期约 1 年，且 `device-ids` 里是**你的手机 UDID**）。

### 第 5 步 · 克隆本套件 + 恢复 key.pem

```bat
git clone git@github.com:kamalovecz/hap_release_kit.git
cd hap_release_kit
```

- 如果第 1 步用了脚本方式 A，`certs\key.pem` 已自动就位；
- 否则手动复制：`C:\Users\<你>\Documents\hap_installer\store\key.pem` → 本套件 `certs\key.pem`。

> `key.pem` 是签名私钥（不入库），没有它签名脚本无法工作。

### 第 6 步 · 同步你的 Profile

```bat
powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -BundleName org.xbgroup.clashboxLTS
```

脚本会自动从工具 store 目录把**你的** p7b 同步到本套件 `profiles\`（覆盖仓库里作者的旧文件）。

### 第 7 步 · 签名

```bat
powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\ClashBox_LTS_V1_unsigned.hap
```

- 自动匹配 Profile、检测原生库自动开代码签名（`-signCode 1`）、推导 compatibleVersion；
- 输出 `output\org.xbgroup.clashboxLTS-signed.hap` 并 `verify-app` 校验；
- 手机在线时会顺带打印"手机 API vs HAP 需求"兼容性检查。

### 第 8 步 · 安装 + 验证

```bat
:: 一步到位：签名+安装（-Replace 可覆盖已装旧版）
powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\ClashBox_LTS_V1_unsigned.hap -Install -Replace
:: 或只安装已签名产物
powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath output\org.xbgroup.clashboxLTS-signed.hap
```

看到 `install bundle successfully` 即成功，手机桌面出现 **ClashBox LTS** 图标。
首次启动 ClashBox 时授予 VPN 权限即可使用。

---

## 🧭 兼容性说明（鸿蒙版本）

本套件面向 **HarmonyOS NEXT（5.0 及以上）**，即基于 OpenHarmony 内核、可运行 `.hap` 应用的系统。

### HarmonyOS 版本 ↔ API 版本对照

| 鸿蒙版本 | API | 典型设备 | 本套件 |
|---|---|---|---|
| HarmonyOS 4.x | 9 / 10 | 老机型(未升级) | ❌ 不适用（AOSP 内核，不能装 HAP） |
| HarmonyOS 5.0.0 | 12 | 首批 NEXT 机型 | ✅ 支持 |
| HarmonyOS 5.0.1 | 17 | Mate 60 系列（实测✅） | ✅ 支持 |
| HarmonyOS 5.0.2 / 5.1 | 18 | Pura 70 等 | ✅ 支持 |
| HarmonyOS 6.0 | 20 | 新旗舰 | ✅ 支持 |

### 关键规则

1. **HAP 有最低系统要求**：`module.json` 里的 `minAPIVersion` 决定最低可运行的 API。
   - 例：ClashBox LTS 1.7.4 = `50005017` → 需要 **API 17（HarmonyOS 5.0.1）及以上**。
   - 脚本自动把 `minAPIVersion` 换算成 compatibleVersion 并写入签名。
2. **安装前自动校验**：`install-hap.ps1` 会读取手机的 `const.product.ohos.apiversion`，
   与 HAP 需求对比，不兼容直接报错并给出提示（不会硬装失败）。
3. **Profile 与设备绑定**：每个 Profile（.p7b）只包含特定手机的 UDID，**换手机必须重新生成**（见第 4 步）。

### 如何查看手机的 API / 鸿蒙版本

- **图形界面**：设置 → 关于本机 → HarmonyOS 版本（如 5.0.1）；
- **命令行**（需已连 hdc）：
  ```bat
  hdc shell param get const.product.ohos.version
  hdc shell param get const.product.ohos.apiversion
  ```

> 如果你的手机还在 HarmonyOS 4.x（无法装 HAP）：请先在 设置→系统→软件更新 升级到 HarmonyOS NEXT，再使用本套件。

---

## 一、仓库内容与目录结构

```
hap_release_kit\
├── scripts\            # PowerShell 脚本(全部入库)
│   ├── build-hap.ps1            # 一键：自动匹配 Profile → 签名 → 校验 → 安装
│   ├── sign-hap.ps1             # 签名（可单独调用）
│   ├── install-hap.ps1          # hdc 安装（含手机 API 兼容性检查）
│   ├── download-clash.ps1       # 从 GitHub Releases 下载最新未签名 HAP
│   ├── download-hap-installer.ps1  # 从作者仓库下载小白调试助手(含 key.pem 同步)
│   ├── refresh-profile.ps1      # Profile 过期/缺失处理(自动从工具 store 同步)
│   └── lib-common.ps1           # 公共函数库(含设备/API 探测)
├── tools\               # 签名与调试工具：signer.exe / hdc.exe / packing_tool.exe 及依赖 DLL(入库)
├── certs\               # 签名材料
│   ├── xiaobai-debug.cer    # 应用证书链(公开证书，入库)
│   ├── xiaobai-debug.p7b    # 工具调试 Profile(入库)
│   ├── key.pem              # ⚠️ 私钥(不入库，见下)
│   └── xiaobai.p12          # ⚠️ 含私钥的密钥库(不入库，见下)
├── profiles\            # 应用 Profile(.p7b，华为云签发，按应用+手机绑定；入库)
├── input\               # 未签名 HAP 放这里(超 GitHub 限制，不入库)
├── output\              # 签名产物(不入库)
├── ext\                 # download-hap-installer.ps1 下载解压的工具(不入库)
├── sources\             # ClashBox 官方仓库 README/LICENSE 等参考资料(入库)
├── 一键签名安装.cmd      # 双击即用
├── 下载最新Clash.cmd     # 双击即用
├── .gitignore
└── README.md
```

### 哪些文件不进 Git 仓库（.gitignore）

| 内容 | 原因 | 克隆后如何恢复 |
|---|---|---|
| `certs\key.pem` | 签名私钥，严禁入库 | 运行 `download-hap-installer.ps1` 自动同步，或从工具 store 手动复制 |
| `certs\xiaobai.p12` | 含私钥的密钥库 | 同上 |
| `input\*.hap` | 超过 GitHub 100 MiB 文件限制 | 用 `download-clash.ps1` 下载，或从 Releases 下载 |
| `output\*.hap` | 签名产物体积大 | 由签名脚本生成 |
| `hap_installer\` | 157 MB 二进制复制品 | 需要时从原工具目录复制 |
| `ext\` | 下载的工具本体 | 由 `download-hap-installer.ps1` 生成 |

> ⚠️ **克隆后第一件事**：让 `certs\key.pem` 就位（方式见第 1/5 步），否则签名脚本无法工作。
> 本仓库不含私钥，任何克隆者拿不到签名能力，只能看到公开证书与 Profile。

## 二、命令速查（常用）

| 想做什么 | 命令 |
|---|---|
| 下载小白调试助手 | `scripts\download-hap-installer.ps1` |
| 下载最新未签名 ClashBox | `scripts\download-clash.ps1` |
| 同步你的 Profile | `scripts\refresh-profile.ps1 -BundleName org.xbgroup.clashboxLTS` |
| 一键签名+安装 | `scripts\build-hap.ps1 -HapPath input\xxx.hap -Install [-Replace]` |
| 只签名 | `scripts\sign-hap.ps1 -HapPath input\xxx.hap -ProfilePath profiles\xxx.p7b -OutPath output\xxx-signed.hap` |
| 只安装 | `scripts\install-hap.ps1 -HapPath output\xxx-signed.hap [-Replace]` |
| 双击快捷 | `一键签名安装.cmd` / `下载最新Clash.cmd` |

## 三、为什么不能用工具的"自动签名"？（背景）

- 工具的自动签名流程需要把"小白调试助手"手机版（含 libsigner.so）装到手机上，
  由它在本机 50424 端口提供签名服务，电脑经 `hdc fport` 连过去。
- 手机版助手自身也需要先签名才能安装，而电脑端给它签名时，内置 `signer.exe`
  **无法加载 p12 私钥**（报"不支持 p12文件 请使用pem格式的私钥"）→ 助手永远装不上 → 50424 永远没人监听 → 每次"请求签名"都报"远程计算机拒绝网络连接"。
- 本套件绕开这条死链：直接用 `signer.exe` + `key.pem`（PEM 私钥）在电脑上完成签名，再 `hdc install`。

## 四、Profile 过期/缺失怎么办（重点）

Profile（.p7b）由**华为云**签发（签名链：HOS Profile Management Debug ← Huawei CBG Software
Signing Service CA ← Huawei CBG Root CA G2），本机无法伪造，只能让工具连华为账号重新生成。

重新生成步骤（需能连华为云，工具内需保持登录；**每台新手机都要重新生成**）：

1. 把该应用的未签名 HAP **拖进小白调试助手**（加入应用列表）；
2. 手机连好后，点**更多 → 重置证书和Profile**（工具会调用华为云为该应用重新生成 Profile）；
3. 运行本套件同步：

```bat
powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -BundleName <包名>
```

脚本会自动从 `C:\Users\<你>\Documents\hap_installer\store\` 把新生成的 p7b 同步到 `profiles\`。
也可手动指定文件导入：`-ProfilePath 新生成的.p7b`。

## 五、排错表

| 现象 | 原因与处理 |
|---|---|
| 签名报 `不支持 p12文件 请使用pem格式的私钥` | keystore 用了 p12。本套件默认用 `certs\key.pem`（工具自己就是从 p12 提取的），无需处理 |
| 签名后安装报 `no signature file` (9568320) | 签名块没写进去（常见于用 p12 签名失败的情况）。用本套件 `sign-hap.ps1` 重签 |
| 安装报 `verify code signature failed` (9568393) | HAP 含原生 .so 但没做代码签名。`sign-hap.ps1` 会自动识别并加 `-signCode 1` |
| 安装报 `min api version` / `install app version is lower` 之类 | **HAP 需要的 API 比手机系统高**。`install-hap.ps1` 会提前拦截并提示；升级鸿蒙或换更新的设备 |
| 手机是 HarmonyOS 4.x，安装报错 | 4.x 基于安卓内核、不支持 HAP。请先升级到 HarmonyOS NEXT（5.0+） |
| 安装报 Profile 相关问题 / `device` 不在列表 | Profile 过期或没包含当前手机 UDID。见「四、Profile 过期/缺失怎么办」 |
| `hdc install` 报 `install bundle already exists` | 同包名已安装，加 `-Replace` 覆盖 |
| `hdc list targets` 为空 | 手机开发者模式/USB调试未开，或驱动未装；换 USB 线/接口，或改用无线调试 |
| 签名报包名不匹配 | `-ProfilePath` 指定的 p7b 属于别的应用，用 `build-hap.ps1` 自动匹配即可 |

## 六、签名参数说明（signer.exe）

核心命令等价于：

```
signer.exe sign-app -mode localSign -keyAlias xiaobai
  -appCertFile  certs\xiaobai-debug.cer
  -profileFile  profiles\<应用>.p7b
  -signAlg      SHA256withECDSA
  -keystoreFile certs\key.pem          ← 注意是 PEM，不是 p12
  -keystorePwd  xiaobai123
  -inFile       <未签名.hap>
  -outFile      <签名.hap>
  -compatibleVersion <API版本>          ← 由 minAPIVersion 自动推导(12/17/18/20...)
  -signCode     1                       ← 含原生 .so 时必填，否则手机拒装
```

## 七、安全提醒与许可

- `certs\key.pem` 是签名私钥（密码 xiaobai123，与工具内置一致），**请勿外传/上传公开仓库**；
- Profile 与具体手机 UDID 绑定，换手机需要重新生成；
- 本套件只做"用你的证书给你的 HAP 签名安装"，请确保 HAP 来源可信；
- 本仓库不含任何私钥材料，可放心公开（仍建议设为 Private）；
- 工具来源：小白调试助手（hap_installer，[github.com/likuai2010/auto-installer](https://github.com/likuai2010/auto-installer)）；
  目标应用：ClashBox（[github.com/xiaobaigroup/ClashBox](https://github.com/xiaobaigroup/ClashBox)），版权归原作者所有，本仓库仅做签名安装的工程化封装。
