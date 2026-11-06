# 环境与方案选择

参考主机为 i5-14600KF、32 GB RAM、RTX 4070、Windows 11 x64，显示输出为 2560×1440 高刷新率。KF CPU 无核显，默认 NVENC 路径依赖 NVIDIA 显卡及有效显示输出。Android 客户端为小米 Pad 6S Pro，手机小米 13 Pro 可使用同一客户端组合。

Sunshine + Moonlight 适合桌面、游戏和三维软件的低延迟画面，参考环境已出现 HEVC NVENC 编码及系统音频采集。实际分辨率、帧率、延迟受网络和客户端解码能力影响。先从 1080p60、HEVC、SDR、10–15 Mbps 起步，再按实际表现提高画质。

电脑处于不能管理路由器的共享/公司/校园网络，因此以 Tailscale 虚拟组网解决跨网可达性，避免依赖公网端口映射。电脑服务自启、账号信任和网络可达性是三项独立条件。

| 替代路径 | 适用条件与取舍 |
|---|---|
| RustDesk | 更偏向办公和通用远控，可自建中继；高动态画面体验需实测 |
| AVNC + UltraVNC | 适合维护与局域网 VNC；跨网还需 VPN/隧道，动态画面不是本方案的重点 |
| Sunshine 公网映射 | 需要路由器权限、可入站公网地址/IPv6和端口策略；当前 VPN 绑定不能直接沿用公网转发 |
| 自建 WireGuard 中心 | 需要公网节点及维护，带宽/地理位置影响体验；仍受 UDP 可达性限制 |
| Tailscale Peer Relay | 当直连困难且 DERP 性能不足时再评估，需常在线且可达的合适节点 |

本仓库的脚本针对当前已验证的 Windows + Tailscale + Sunshine 路径。没有打包其他远控程序或承诺在所有网络上直连。

[Moonlight 官方设置指南](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide) · [Sunshine 官方文档](https://docs.lizardbyte.dev/projects/sunshine/latest/)
