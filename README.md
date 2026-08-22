# hap_release_kit — HarmonyOS HAP 签名安装套件（可复制版）

![Platform](https://img.shields.io/badge/platform-Windows-blue)
![GitHub](https://img.shields.io/badge/git-git%20lfs--important)

一套**自包含、可整体复制/克隆到任意电脑**的 HAP 签名/安装工具集。
针对"小白调试助手（hap_installer 3.1.0）自动签名报 `127.0.0.1:50424 连接被拒绝`"的问题，
改用**本机 signer.exe 直接签名 + hdc 安装**的稳定链路，签名产物经 `verify-app` 校验、可正常安装到 Mate 60。

> 已验证：ClashBox LTS 1.7.4（含 7 个原生 .so）→ 签名 → `hdc install` 成功。
> 全程离线完成，不依赖手机端"小白调试助手"和 50424 端口。
> 远端仓库: `git@github.com:kamalovecz/hap_release_kit.git`

---

## 一、仓库内容与目录结构

```
hap_release_kit\
├── scripts\            # PowerShell 脚本(全部入库)
│   ├── build-hap.ps1        # 一键：自动匹配 Profile → 签名 → 校验 → 安装
│   ├── sign-hap.ps1         # 签名（可单独调用）
│   ├── install-hap.ps1      # hdc 安装（可单独调用）
│   ├── download-clash.ps1   # 从 GitHub Releases 下载最新未签名 HAP
│   ├── refresh-profile.ps1  # Profile 过期/缺失处理(自动从工具 store 同步)
│   └── lib-common.ps1       # 公共函数库
├── tools\               # 签名与调试工具：signer.exe / hdc.exe / packing_tool.exe 及依赖 DLL(入库)
├── certs\               # 签名材料
│   ├── xiaobai-debug.cer    # 应用证书链(公开证书，入库)
│   ├── xiaobai-debug.p7b    # 工具调试 Profile(入库)
│   ├── key.pem              # ⚠️ 私钥(不入库，见下)
│   └── xiaobai.p12          # ⚠️ 含私钥的密钥库(不入库，见下)
├── profiles\            # 应用 Profile(.p7b，华为云签发，按应用+手机绑定；入库)
├── input\               # 未签名 HAP 放这里(超 GitHub 限制，不入库)
├── output\              # 签名产物(不入库)
├── sources\             # ClashBox 官方仓库 README/LICENSE 等参考资料(入库)
├── 一键签名安装.cmd      # 双击即用
├── 下载最新Clash.cmd     # 双击即用
├── .gitignore
└── README.md
```

### 哪些文件不进 Git 仓库（.gitignore）

| 内容 | 原因 | 克隆后如何恢复 |
|---|---|---|
| `certs\key.pem` | 签名私钥，严禁入库 | 从本机 `C:\Users\<你>\Documents\hap_installer\store\key.pem` 复制回来 |
| `certs\xiaobai.p12` | 含私钥的密钥库 | 同上，从工具 store 复制 |
| `input\*.hap` | 超过 GitHub 100 MiB 文件限制 | 用 `scripts\download-clash.ps1` 下载，或手动放入 |
| `output\*.hap` | 签名产物体积大 | 由签名脚本生成 |
| `hap_installer\` | 157 MB 二进制复制品 | 需要时从原工具目录复制 |

> ⚠️ **克隆后第一件事**：把 `key.pem` 复制回 `certs\`（否则签名脚本无法工作）。
> 本仓库不含私钥，任何克隆者拿不到签名能力，只能看到公开证书与 Profile。

## 二、快速上手

### 场景 A：签名 + 安装已有的未签名 HAP（如 ClashBox）

```bat
:: 双击运行，或命令行执行：
powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\ClashBox_LTS_V1_unsigned.hap -Install
```

脚本会自动：读取 HAP 包名 → 匹配 `profiles\` 里对应的 Profile → 检测原生库自动开代码签名 →
调用 `signer.exe` 签名 → `verify-app` 校验 → `hdc install` 安装。

### 场景 B：下载最新的 ClashBox / ClashNext 未签名 HAP 并安装

```bat
powershell -ExecutionPolicy Bypass -File scripts\download-clash.ps1
:: 下载完成后
powershell -ExecutionPolicy Bypass -File scripts\build-hap.ps1 -HapPath input\<下载的文件名> -Install
```

下载源优先级：GitHub Releases（xiaobaigroup/ClashBox 及组织内 clash 相关仓库）→ HarmonyOS-Haps 合集直链 →
手动放入 `input\`。国内网络访问 GitHub 受限时，请直接把未签名 HAP 拷进 `input\` 目录（脚本会提示）。

> 说明：xiaobaigroup 组织下**没有独立的 clashnext 仓库/下载**，官方产品即 **ClashBox LTS**
> （`org.xbgroup.clashboxLTS`）。旧版 `org.xbstudio.clashnext`（ClashNext）Profile 已过期，详见第四节。

### 场景 C：只签名 / 只安装

```bat
:: 只签名（输出到 output\）
powershell -ExecutionPolicy Bypass -File scripts\sign-hap.ps1 -HapPath input\xxx.hap -ProfilePath profiles\org_xbgroup_clashboxLTS.p7b -OutPath output\xxx-signed.hap

:: 只安装（要求 HAP 已签名；-Replace 可覆盖已装的同包名旧版本）
powershell -ExecutionPolicy Bypass -File scripts\install-hap.ps1 -HapPath output\xxx-signed.hap [-Replace]
```

## 三、为什么不能用工具的"自动签名"？（背景）

- 工具的自动签名流程需要把"小白调试助手"手机版（含 libsigner.so）装到手机上，
  由它在本机 50424 端口提供签名服务，电脑经 `hdc fport` 连过去。
- 手机版助手自身也需要先签名才能安装，而电脑端给它签名时，内置 `signer.exe`
  **无法加载 p12 私钥**（报"不支持 p12文件 请使用pem格式的私钥"）→ 助手永远装不上 → 50424 永远没人监听 → 每次"请求签名"都报"远程计算机拒绝网络连接"。
- 本套件绕开这条死链：直接用 `signer.exe` + `key.pem`（PEM 私钥）在电脑上完成签名，再 `hdc install`。

## 四、Profile 过期/缺失怎么办（重点）

Profile（.p7b）由**华为云**签发（签名链：HOS Profile Management Debug ← Huawei CBG Software
Signing Service CA ← Huawei CBG Root CA G2），本机无法伪造，只能让工具连华为账号重新生成。

当前套件内：
| Profile | 应用 | 状态 |
|---|---|---|
| org_xbgroup_clashboxLTS.p7b | ClashBox LTS | ✅ 有效至 2027-08-21 |
| org_xbstudio_clashnext.p7b | ClashNext | ⚠️ 已过期（2026-06-08），需重新生成 |

重新生成步骤（需能连华为云，工具内需保持登录）：

1. 把该应用的未签名 HAP **拖进小白调试助手**（加入应用列表）；
2. 手机连好后，点**更多 → 重置证书和Profile**（工具会调用华为云为该应用重新生成 Profile）；
3. 运行本套件同步：

```bat
powershell -ExecutionPolicy Bypass -File scripts\refresh-profile.ps1 -BundleName org.xbstudio.clashnext
```

脚本会自动从 `C:\Users\<你>\Documents\hap_installer\store\` 把新生成的 p7b 同步到 `profiles\`。
也可手动指定文件导入：`-ProfilePath 新生成的.p7b`。

## 五、排错表

| 现象 | 原因与处理 |
|---|---|
| 签名报 `不支持 p12文件 请使用pem格式的私钥` | keystore 用了 p12。本套件默认用 `certs\key.pem`（工具自己就是从 p12 提取的），无需处理 |
| 签名后安装报 `no signature file` (9568320) | 签名块没写进去（常见于用 p12 签名失败的情况）。用本套件 `sign-hap.ps1` 重签 |
| 安装报 `verify code signature failed` (9568393) | HAP 含原生 .so 但没做代码签名。`sign-hap.ps1` 会自动识别并加 `-signCode 1` |
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
  -compatibleVersion <API版本>          ← 由 minAPIVersion 自动推导
  -signCode     1                       ← 含原生 .so 时必填，否则手机拒装
```

## 七、安全提醒与许可

- `certs\key.pem` 是签名私钥（密码 xiaobai123，与工具内置一致），**请勿外传/上传公开仓库**；
- Profile 与具体手机 UDID 绑定，换手机需要重新生成；
- 本套件只做"用你的证书给你的 HAP 签名安装"，请确保 HAP 来源可信；
- 本仓库不含任何私钥材料，可放心公开（仍建议设为 Private）；
- 工具来源：小白调试助手（hap_installer，[github.com/likuai2010/auto-installer](https://github.com/likuai2010/auto-installer)）；
  目标应用：ClashBox（[github.com/xiaobaigroup/ClashBox](https://github.com/xiaobaigroup/ClashBox)），版权归原作者所有，本仓库仅做签名安装的工程化封装。
