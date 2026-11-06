# Tailscale 多系统安装与认证

本仓库自动部署主机脚本针对 Windows。以下是其他平台的安装入口，不代表 Sunshine 在其他系统的无人值守桌面采集也已经验证。

| 系统 | 安装与登录 |
|---|---|
| Windows | 官方 MSI 安装后，托盘 Log in，在浏览器登录自己的账号；远程主机启用 Run unattended |
| Android | 官方 APK 或应用商店版本，登录相同 tailnet，批准本机 VPN 请求并保持 Connected |
| Linux | 使用官方发行版仓库/安装流程，启动 `tailscaled` 系统服务，再 `sudo tailscale up` 完成认证 |
| macOS | 从官方入口选择 Standalone 或 App Store 版本，按提示授权系统网络扩展并登录；不要混装多个变体 |

Linux 官方脚本可以先保存、审阅再执行：

```sh
curl -fsSL https://tailscale.com/install.sh -o tailscale-install.sh
sh tailscale-install.sh
sudo tailscale up
```

认证由用户在官方页面完成，不在仓库预置 Auth key。完成后检查 `tailscale status`，并用另一台已加入网络的设备 `tailscale ping <peer-ip>` 验证隧道；再测试实际应用。

Windows 的 unattended 让已认证配置在注销/重启后保持服务可用。Linux 通常由系统守护进程运行；macOS 变体的登录会话和常驻行为应以当前官方文档为准，不应直接套用 Windows 的开关。

[Windows](https://tailscale.com/docs/install/windows) · [Android](https://tailscale.com/docs/install/android) · [Linux](https://tailscale.com/download/linux) · [macOS](https://tailscale.com/docs/concepts/macos-variants) · [无人值守](https://tailscale.com/docs/how-to/run-unattended)
