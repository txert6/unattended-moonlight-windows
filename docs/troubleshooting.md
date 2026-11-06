# 排查与回滚

| 现象 | 检查顺序 |
|---|---|
| 电脑离线 | 通电/未休眠 → 网络准入 → Tailscale 服务自动运行 → unattended → 节点到期/审批 → 健康告警 |
| Moonlight 找不到电脑 | 手动填写正确 VPN IP；虚拟网络没有自动发现并不代表连接失败 |
| 无法连接 | 平板浏览器访问电脑 `http://<PC_TAILSCALE_IP>:47989/serverinfo`，再查 TCP 47984/48010、主机和 tailnet 策略 |
| XML 正常但无法启动 | HTTP 仅证明一个端口；仍需验证证书、RTSP 和 UDP 视频/控制/音频 |
| 重复 PIN/客户端未授权 | 检查对应旧证书身份，备份后只移除该客户端，再用实时 PIN 配对一次；不要清空全部客户端 |
| 黑屏/无视频 | 显示输出、锁屏/会话、显卡驱动/NVENC 与 UDP 47998–48000，不能只归咎防火墙 |
| 无声 | Moonlight 音频选项、Windows 音频设备及 Sunshine 音频采集日志 |
| 卡顿/断流 | `tailscale status` / `ping` / `netcheck` 区分 direct 和 relay；查上传、丢包、Wi-Fi，再降低码率和分辨率 |
| 重启后才失败 | Windows 是否进入桌面、代理/门户是否就绪、服务是否启动、VPN 绑定地址是否存在、显示输出是否有效 |
| 更改账号/重装后失效 | 核对节点身份/IP、管理凭据与证书、服务和自启路径；不要先反复重新配对 |

命令示例：

```powershell
Get-Service SunshineService,Tailscale
& "$env:ProgramFiles\Tailscale\tailscale.exe" status
& "$env:ProgramFiles\Tailscale\tailscale.exe" ping '<TABLET_TAILSCALE_IP>'
& "$env:ProgramFiles\Tailscale\tailscale.exe" netcheck
sc.exe qfailure SunshineService
.\scripts\Get-DeploymentStatus.ps1
```

Sunshine 编码能力探测可能输出不支持 YUV444 等信息，若随后找到可用编码器并成功建立实际会话，不能仅凭探测期 Error 判断运行失败。查看与失败尝试时间相符的日志。

回滚主机配置：从 `%LOCALAPPDATA%\UnattendedMoonlightDeploy` 选择本次配置前 `.conf` 备份，管理员停止 SunshineService，恢复到安装目录的 `config\sunshine.conf`，再启动服务。先检查备份的绑定地址仍在本机；管理凭据和配对状态没有被配置脚本改写。

本仓库新增规则名为 `UnattendedMoonlight-Tailscale-TCP` 和 `UnattendedMoonlight-Tailscale-UDP`，回滚时只处理这两条规则，不删除其他远控/代理规则。电源和服务恢复策略请按自己的需要还原。Clash 快捷方式可单独移除，不需要删除整个启动文件夹。

日志、诊断报告和原始配置可能包含地址、设备名、身份或订阅，请在公开 issue 前清理。
