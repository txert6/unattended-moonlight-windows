# 本机 Sunshine 配对工具

`src/SunshinePairing` 是本部署使用的 WinForms 小工具源码，`Build-PairingApp.ps1` 可重新编译；Release ZIP 中包含相同源码和编译产物。程序无需管理员运行，不依赖浏览器。

先在 Sunshine 创建自己的管理账号。复制 `config/admin-credentials.example.txt` 到仓库之外，在本机填写用户名和密码。双击工具，选择“导入管理凭据”，导入自己的文件。完成后的明文文件自行放在受限目录或移除，绝不能提交 Git。

工具只连接当前电脑接口上的 Sunshine，按当前 `sunshine.conf` 识别地址与端口。首次导入获取本机 TLS 证书 SHA-256，认证请求固定该证书；后续不使用代理、不跟随重定向。凭据以 Windows DPAPI CurrentUser 保存到 `%LOCALAPPDATA%\SunshinePairing\credentials.dpapi`，换电脑/账户需重新导入。程序中没有内嵌密码。

Android Moonlight 点击电脑并保持当前 PIN 页面亮屏 → 工具选择对应请求 → 输入当前 4 位 PIN → 提交一次。工具定时刷新请求，提交时暂停刷新，避免重复提交；PIN 不保存到文件或日志。更换管理密码或重建服务证书后需要重新导入本机凭据。

配对成功后日常直接打开 Desktop，不再使用此工具。不要部署自动接受任意新设备的配对服务。

锁定 Sunshine 版本曾遇到重复证书身份：同一客户端反复配对产生多个相同证书记录，造成“电脑成功但客户端未授权”。必须重配时，先备份私密状态，仅移除对应旧设备，再生成新 PIN 配对一次，保留其他设备。工具不会自动删除设备记录。[上游问题 #5696](https://github.com/LizardByte/Sunshine/issues/5696)

此工具只处理本机 Sunshine 配对，不建立 VPN、不自动解锁 Windows，也不能独立远程唤醒关机电脑。
