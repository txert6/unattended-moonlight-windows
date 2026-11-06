# Android 手机/平板

1. 用 `Get-Dependencies.ps1 -Platform android` 下载并校验官方 Moonlight 和 Tailscale APK，或从各项目官方渠道安装。APK 不是修改版，不要求 root。
2. 打开 Tailscale，以自己的账号加入与电脑相同的 tailnet，确认 Connected。若使用应用分流，确保 Moonlight 流量进入 Tailscale。
3. HyperOS 允许 Tailscale 自启动、后台运行，电池策略设置为不限制。系统如果提供“始终开启 VPN”可使用；避免另一个 VPN 替换它。
4. Moonlight → `+` → 电脑 Tailscale IPv4 → 点击电脑。首次保持 4 位 PIN 页面在前台直到握手完成，可从另一设备操作电脑管理页面。
5. 配对完成后点击 Desktop。先用 1080p60、HEVC、SDR、10–15 Mbps；用实际画面、触控和声音验收。

日常不需要重新配对。不同手机/平板各有独立证书，不共享应用数据或证书。外网测试时，可让 Wi-Fi 平板连接手机移动数据热点，确保与电脑不在同一网络。

触控行为由 Moonlight 的鼠标/触屏模式决定；平板手势并不等于 Windows 原生多点触控。需要长时间办公时可使用蓝牙/USB 键鼠。当前默认关闭虚拟游戏手柄，不包含相关驱动。

[Moonlight Android Releases](https://github.com/moonlight-stream/moonlight-android/releases) · [Tailscale Android](https://tailscale.com/download/android) · [Android VPN](https://developer.android.com/develop/connectivity/vpn#always-on)
