# Clash Verge 与启动顺序

Clash 不是 Tailscale 的固定前置依赖。如果网络能直接访问 Tailscale 的协调/中继及 UDP，则不一定需要代理；如果受限，则可能影响登录、上线或中继。参考环境未停用代理做对照，不能据此宣称“无代理必然失败”。

参考环境已有 Clash Verge Rev 2.5.10、自动运行的 Clash Verge Service、正常 TUN 和静默启动。内置自启开关未能保存，最终使用 Windows 当前用户启动文件夹快捷方式；Windows 已识别该启动项，并在用户重启后看到应用自动运行。

脚本只注册已安装的 `clash-verge.exe`，不下载代理配置、不修改节点、订阅、DNS或默认代理。建议先确认已有配置能够联网，并保持应用内静默启动；当前用户必须能够进入桌面，启动文件夹不会在 Windows 登录前代替用户拉起界面。

不要添加多份自启。若内置自启正常，可直接使用它；已有内置/任务自启时不再运行本仓库的快捷方式注册脚本。也不要把 Tailscale 的 Windows 服务机械设置为依赖 Clash 服务：后台服务启动不代表 TUN、节点和网络均已就绪。

重启后等待网络和应用初始化，Tailscale 服务正常重连，Sunshine 通过系统服务继续运行。若代理订阅失效，缓存节点即便暂时可用，也不能保证后续持续联网，应在原服务商处核查，禁止公开订阅链接。

[Windows 启动文件夹方法](https://support.microsoft.com/en-us/windows/experience/startup-boot/configure-startup-applications-in-windows) · [Clash 服务模式说明](https://www.clashverge.dev/guide/term.html)
