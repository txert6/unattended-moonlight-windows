# 网络、端口和认证

两端加入同一 tailnet，在 Moonlight 手动添加电脑的 Tailscale IPv4。虚拟网络通常不转发局域网自动发现广播，所以“列表没有自动出现”不等于无法访问。

Tailscale 尝试建立 UDP 直连；网络条件不满足时使用中继。出站 TCP 443 用于协调/DERP，UDP 3478 用于 STUN，直连默认本地源 UDP 41641，目的端口可变。一般不用路由器端口映射；中继可能比直连更慢。

VPN 内 Sunshine 默认流量：TCP 47989（发现）、47984（HTTPS 协议）、48010（RTSP）；UDP 47998（视频）、47999（控制）、48000（音频）。管理网页 TCP 47990 只供可信本机管理，不加入客户端串流允许规则。更改基础端口后必须同步调整规则与客户端。

`Configure-Host.ps1` 仅允许明确指定的客户端 IP，从本机 Tailscale IP/接口访问上述串流端口。它不启用全局防火墙，也不删除已有宽泛允许规则；如果防火墙关闭，这些规则并不执行过滤。需要审阅现有规则及 tailnet grants/ACL，才可以认为访问边界已收紧。

管理界面仍需要自己的强密码。已配对 Moonlight 使用保存的证书自动认证；新客户端首次必须完成 PIN。重装应用、清除数据或撤销身份后需要重新配对。请勿提交 `sunshine_state.json`、私钥、DPAPI 密文或凭据文件。

长期无人值守需在 [Tailscale Machines](https://console.tailscale.com/admin/machines)中对可信电脑关闭节点密钥到期；保留账号认证和设备撤销能力。只开启 unattended 不会自动关闭到期。丢失设备时同时撤销 Tailscale 节点和 Sunshine 对应客户端。

电脑必须通电、网络自动接入、Windows 能进入所需会话。BIOS 密码、BitLocker 启动 PIN、网络门户等发生在系统服务可用之前，不能靠 Sunshine 远程代替本机完成。Windows 自动登录属于单独选择，部署脚本不保存或修改 Windows 密码。

[Tailscale 端口](https://tailscale.com/docs/reference/faq/firewall-ports) · [无人值守](https://tailscale.com/docs/how-to/run-unattended) · [密钥到期](https://tailscale.com/docs/features/access-control/key-expiry) · [Moonlight 设置](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
