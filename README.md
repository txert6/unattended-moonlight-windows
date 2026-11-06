# Windows 无人值守串流：Sunshine + Moonlight + Tailscale

将 Windows 桌面通过加密虚拟网络串流到 Android 手机或平板。完成首次登录和配对后，电脑重启进入桌面即可自动运行，外出时只在平板打开 Moonlight → Desktop，不需要电脑端再确认。

本仓库包含可复用部署脚本、配置模板、依赖版本和 SHA-256、配对工具源码、故障排查及验收文档。**这里没有可直接复用的个人密码、订阅、设备证书或真实设备 IP。** 第三方安装包由脚本从官方源获取，不随本仓库或 ZIP 重新分发。

参考环境已完成一次 Windows 重启后的无人值守跨网验收：Intel i5-14600KF、32 GB RAM、RTX 4070、Windows 11 x64、Android 小米 Pad 6S Pro。编码使用 HEVC NVENC；小米 13 Pro 使用相同 Android 部署流程。完整范围见 [验收记录](docs/verification.md)。

## 环境要求

- Windows 11 x64；脚本支持 Windows PowerShell 5.1 / PowerShell 7。其他 Windows 版本请先核对上游支持范围。
- NVIDIA NVENC 可用显卡及驱动，默认 `encoder=nvenc`。AMD/Intel 参数已预留，但未按此参考环境实测。
- 有效显示输出；关闭显示器后是否保留输出需要另测，必要时另配 EDID 模拟或兼容的虚拟显示方案。
- 安装和主机配置需要一次管理员权限；日常已配对连接无需管理员确认。
- 电脑持续供电、联网，网络允许 Tailscale 的协调服务及所需直连/中继流量。
- Android 安装官方 Moonlight 与 Tailscale，加入同一 tailnet。建议先用 1080p60、HEVC、SDR、10–15 Mbps。
- 可选：已经安装并配置好的 Clash Verge Rev。仓库仅配置它的登录自启，不提供代理订阅。
- 配对工具编译使用 Windows .NET Framework 4.x 的 `csc.exe` 与 WinForms，Windows 11 参考环境具备这些组件，无 NuGet 依赖。

## 部署步骤

首次部署需要完成自己的账号登录、Sunshine 管理密码与一次 PIN 配对。这些是建立信任的步骤；免确认指之后的正常连接，不是自动接受陌生客户端。

### 1. 下载并校验官方依赖

解压 Release ZIP 或克隆本仓库，在仓库目录打开 PowerShell：

```powershell
.\scripts\Get-Dependencies.ps1 -Platform all
```

文件保存在被 Git 忽略的 `downloads/`。下载和安装前均验证锁定 SHA-256，Windows MSI 还检查 Authenticode；发现不匹配就停止。版本与来源见 [依赖清单](config/dependencies.lock.json)。缓存已有文件可加 `-VerifyOnly`，不会重新下载。

### 2. 安装 Windows 服务

在管理员 PowerShell 中运行：

```powershell
.\scripts\Install-Dependencies.ps1
```

脚本保留已经安装的 Sunshine/Tailscale，避免覆盖现有配对；不会强制重启。它不创建账户或登录凭据。安装日志保存在当前用户 `%LOCALAPPDATA%\UnattendedMoonlightDeploy`。

如果执行策略阻止脚本，可审阅源码后仅对本次进程使用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-Dependencies.ps1
```

### 3. 登录 Tailscale，确定自己的设备地址

电脑托盘 Tailscale → Log in，在官方浏览器页面登录自己的账号。Android 安装 Tailscale，登录同一 tailnet，记录手机/平板的 Tailscale IPv4。不要把登录链接、密码、Auth key 发到 issue 或提交到仓库。

电脑运行 `tailscale status` 或从应用查看地址。没有把 DNS、子网路由、Exit node 的变更合并进脚本，现有网络设置保留。

### 4. 配置 Sunshine、无人值守和受限规则

将下面的占位符替换为真实的 **平板/手机** Tailscale IPv4，不是电脑自己的 IP：

```powershell
.\scripts\Configure-Host.ps1 `
  -TrustedClientIPs @('<TABLET_TAILSCALE_IP>', '<PHONE_TAILSCALE_IP>') `
  -DisableSleepOnAC
```

只有一个客户端时传一个地址即可。脚本自动识别本机 Tailscale IPv4，也可用 `-ComputerTailscaleIP` 指定；`-WhatIf` 可以先查看计划。

配置内容：

- Sunshine/Tailscale 系统服务自动启动；Tailscale 开启 unattended。
- Sunshine 仅绑定本机 VPN IPv4，UPnP 关闭，使用 NVENC，保留未知配置项、管理密码和配对状态。
- 配置前备份 Sunshine `.conf` 到当前用户的受限本地状态目录。
- Sunshine 服务异常退出后按 15/30/60 秒重启，一天重置故障计数；保留 Tailscale 原有恢复策略。
- 只给指定客户端和 VPN 接口添加 TCP 47984/47989/48010、UDP 47998/47999/48000 的允许规则。
- 可选禁止交流电下自动睡眠与休眠，不更改电池供电设置。

脚本可能短暂重启 Sunshine 以应用配置，请在无人使用当前串流时执行。它不修改全局防火墙启用状态、现有宽泛规则、tailnet grants/ACL 或 Windows 登录设置。规则存在不等于防火墙正在过滤；详见 [网络与认证](docs/network-and-auth.md)。

### 5. 设置自己的 Sunshine 管理账号并首次配对

在电脑本机打开脚本输出的 `https://<PC_TAILSCALE_IP>:47990/`。核对目标属于自己电脑，再处理其自签名证书提示；新安装请创建自己的管理账号。

Android Moonlight → `+` → 填写电脑 Tailscale IPv4 → 点击电脑 → 保持 PIN 页面在前台。电脑 Sunshine 管理页输入当前 PIN，配对一次后打开 Desktop。之后正常连接使用证书自动认证，无需再次输入 PIN 或管理密码。

可选桌面配对工具：

```powershell
.\scripts\Build-PairingApp.ps1
```

生成 `artifacts/SunshinePairing.exe`。首次在电脑上导入自己的管理凭据文件（格式见 [示例](config/admin-credentials.example.txt)，完成后的文件放在仓库外），工具将凭据保存为当前用户的 DPAPI 密文并固定本机 TLS 证书。完整说明见 [配对工具](docs/pairing-tool.md)。已有正常配对不要反复重新配对。

### 6. 长期无人值守与 Clash 可选自启

在 Tailscale [设备管理](https://console.tailscale.com/admin/machines)中核对自己的电脑，对可信的远程主机选择 **Disable key expiry**。这属于账号侧操作，脚本不会代替你登录或修改云端策略。

电脑应能自行进入所需 Windows 桌面。若存在登录、BitLocker 启动 PIN 或网络门户，需分别处理这些前置条件；本项目不保存 Windows 密码、不绕过登录保护。

已使用 Clash Verge 的电脑，可开启应用内静默启动、保留已有服务/TUN/节点配置，然后运行：

```powershell
.\scripts\Enable-ClashStartup.ps1 -ExecutablePath 'D:\Apps\Clash Verge\clash-verge.exe'
```

它添加当前账户启动文件夹快捷方式，适用于进入桌面后启动。不要与已经生效的内置自启/计划任务重复配置。是否必须依赖代理取决于实际网络；本方案没有以停用代理作对照。详见 [Clash 与启动顺序](docs/clash-startup.md)。

### 7. 验证与日常使用

```powershell
.\scripts\Get-DeploymentStatus.ps1
```

该脚本只读检查。输出有本机网络信息，保存时请放在仓库外，发布前必须清理。电脑端 HTTP 正常不能替代平板音视频、控制和外网验收。

保存工作后重启，让电脑自行进入桌面，不手动打开任何组件。平板连接手机移动数据热点，保持 Tailscale Connected → Moonlight → 电脑 VPN IP → Desktop，测试画面、操作、音频与断开重连。

日常只需电脑通电联网，平板重复上述连接路径。电脑关机或断电时，自己的 Tailscale 服务无法唤醒自己；远程开机需要另有局域网常在线唤醒节点等条件。

## 网络端口

| 范围 | 端口/条件 |
|---|---|
| 外网协调与 DERP | 出站 TCP 443，DNS 正常 |
| NAT 探测 | 出站 UDP 3478 及返回流量 |
| Tailscale 直连 | 允许 UDP 出站及返回，默认本地源端口 41641，对端端口可变 |
| VPN 内 Sunshine | TCP 47984、47989、48010；UDP 47998–48000 |
| 管理网页 | TCP 47990，供本机管理；不加入远程串流规则 |

无需公网 IP 或路由器端口映射。受限网络可能使用加密中继，性能需实测。Tailscale-only 绑定不能替代主机防火墙及 tailnet 访问策略。

## 目录结构

```text
README.md
NOTICE.md                       第三方来源与发布边界
config/
  dependencies.lock.json        官方依赖版本、来源、SHA-256
  deployment.example.json       部署参数规划模板
  sunshine.conf.example         脱敏配置模板
  admin-credentials.example.txt 仅格式示例，禁止填写后提交
scripts/
  Common.ps1                    参数校验、配置合并、受限备份目录
  Get-Dependencies.ps1          下载/校验依赖
  Install-Dependencies.ps1      安装缺失的 Windows 服务
  Configure-Host.ps1            配置无人值守主机
  Enable-ClashStartup.ps1       当前用户 Clash 登录自启
  Get-DeploymentStatus.ps1      只读诊断
  Build-PairingApp.ps1          编译 WinForms 配对工具
  Test-Package.ps1              语法、模板、公开包检查
  Build-Package.ps1             生成 Release ZIP 与 SHA-256
src/SunshinePairing/             C# 源码、图标、清单
docs/                           网络、安装、配对、验收及排查
downloads/ private/ artifacts/   本地生成，Git 忽略，不进入发布包
```

## 打包、验证与维护

```powershell
.\scripts\Test-Package.ps1
.\scripts\Build-Package.ps1 -Version v1.0.0
```

Release ZIP 使用明确的目录允许清单，包含全部公开部署源文件和重新编译的配对工具；排除 `.git`、下载缓存、凭据、证书、原始日志和本机运行状态。随 ZIP 提供 SHA-256。第三方大安装包请由下载脚本获取，避免在源码仓库中镜像分发。

升级时先备份自己的 Sunshine 配置与受保护的状态，在可恢复现场时验证官方新版本和哈希，再更新依赖清单。本仓库锁定的是已验收版本，不自动追逐最新版。

详细文档：[环境与选择](docs/environment-and-design.md) · [网络与认证](docs/network-and-auth.md) · [Android](docs/android.md) · [多系统 Tailscale](docs/tailscale-multi-os.md) · [Clash](docs/clash-startup.md) · [配对工具](docs/pairing-tool.md) · [排查](docs/troubleshooting.md) · [验收](docs/verification.md) · [发布与隐私](docs/publication.md)
