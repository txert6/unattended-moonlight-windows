# 验收记录（公开脱敏版）

参考环境：Windows 11 x64、i5-14600KF、32 GB、RTX 4070；Android 小米 Pad 6S Pro。Sunshine、Tailscale、Moonlight 版本见依赖清单，可选 Clash Verge Rev 为 2.5.10。

原部署已完成：

1. Sunshine/Tailscale 服务自动启动，Tailscale unattended 开启，交流电自动睡眠/休眠关闭。
2. Sunshine 服务故障重启动作已设置；绑定 VPN 地址，UPnP 关闭；配对身份保持有效。
3. Clash 使用当前用户启动文件夹静默自启，保留原 TUN/服务模式。
4. 用户重启 Windows，电脑按原有设置自行进入桌面；之后只操作平板，从非局域网完成连接。
5. 电脑启动时间、Clash 进程启动时间及随后 Sunshine 的 CLIENT CONNECTED、HEVC NVENC、音频采集记录相符；系统服务 Running + Automatic、Tailscale 无健康告警。

这证明参考环境下的“重启 → 自动运行 → 已配对平板跨网连接”可用，不代表所有 GPU/网络均已验证。没有把物理断电再上电、未登录会话、锁屏、显示器断电或长时间固定帧率标记为已验收。

公开仓库不附原始日志、设备 IP、UUID、证书或管理凭据；完整私密记录保留在原电脑，不进入发布包。

对新设备的验收：保持已配对应用数据，在可恢复现场时保存工作并重启，不手动启动组件；平板改用手机移动数据热点，保持 Tailscale 在线，验证 Desktop 画面/操作/音频与断开重连。另行测试自己需要的锁屏/关屏和长时间稳定性。
