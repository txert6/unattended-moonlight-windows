using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace SunshinePairing {
    public sealed class Credentials {
        public string Username { get; set; }
        public string Password { get; set; }
        public string CertificateHash { get; set; }
    }

    public static class LocalSunshine {
        public static readonly string Install = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Sunshine");
        public static string Hash(byte[] value) {
            using (var sha = SHA256.Create()) return BitConverter.ToString(sha.ComputeHash(value)).Replace("-", "");
        }
        public static bool IsLocalAddress(string host) {
            IPAddress address;
            if (!IPAddress.TryParse(host.Trim('[', ']'), out address)) return false;
            if (IPAddress.IsLoopback(address)) return true;
            return NetworkInterface.GetAllNetworkInterfaces().Any(n => n.GetIPProperties().UnicastAddresses.Any(a => a.Address.Equals(address)));
        }
        public static Uri Endpoint() {
            var values = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var raw in File.ReadAllLines(Path.Combine(Install, "config", "sunshine.conf"))) {
                string line = raw.Trim();
                if (line.StartsWith("#") || !line.Contains("=")) continue;
                int split = line.IndexOf('=');
                values[line.Substring(0, split).Trim()] = line.Substring(split + 1).Trim();
            }
            string host;
            if (!values.TryGetValue("bind_address", out host) || String.IsNullOrWhiteSpace(host) || host == "0.0.0.0" || host == "::") host = "127.0.0.1";
            if (!IsLocalAddress(host)) throw new InvalidOperationException("Sunshine 的监听地址不是本机地址，请检查电脑网络配置。");
            int port = 47989;
            string configured;
            if (values.TryGetValue("port", out configured) && (!Int32.TryParse(configured, out port) || port < 1029 || port > 65514))
                throw new InvalidOperationException("Sunshine 端口设置无效。");
            return new UriBuilder("https", host, port + 1).Uri;
        }
        public static string CertificateHash() {
            // First import only: fetch the certificate from an address assigned to
            // this PC, before sending any HTTP request or administrator credentials.
            // Later authenticated requests must match this saved SHA-256 fingerprint.
            var endpoint = Endpoint();
            IPAddress address = IPAddress.Parse(endpoint.Host.Trim('[', ']'));
            if (!IsLocalAddress(endpoint.Host)) throw new InvalidOperationException("只允许导入本机 Sunshine 的证书。");
            using (var tcp = new TcpClient(address.AddressFamily)) {
                var connect = tcp.ConnectAsync(address, endpoint.Port);
                if (!connect.Wait(5000)) throw new InvalidOperationException("连接本机 Sunshine 超时。");
                using (var tls = new SslStream(tcp.GetStream(), false, (sender, cert, chain, errors) => true)) {
                    tls.ReadTimeout = tls.WriteTimeout = 5000;
                    var authenticate = tls.AuthenticateAsClientAsync(endpoint.Host, null, System.Security.Authentication.SslProtocols.Tls12, false);
                    if (!authenticate.Wait(5000)) throw new InvalidOperationException("本机 Sunshine 的 TLS 握手超时。");
                    if (tls.RemoteCertificate == null) throw new InvalidOperationException("未取得 Sunshine 证书。");
                    return Hash(tls.RemoteCertificate.GetRawCertData());
                }
            }
        }
    }

    public static class Vault {
        public static readonly string Folder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SunshinePairing");
        public static readonly string FilePath = Path.Combine(Folder, "credentials.dpapi");
        static readonly byte[] Entropy = Encoding.UTF8.GetBytes("SunshinePairing/current-user/v1");
        public static Credentials Load() {
            if (!File.Exists(FilePath)) throw new InvalidOperationException("请先导入本机的 Sunshine 管理凭据文件。");
            byte[] clear = ProtectedData.Unprotect(File.ReadAllBytes(FilePath), Entropy, DataProtectionScope.CurrentUser);
            try { return new JavaScriptSerializer().Deserialize<Credentials>(Encoding.UTF8.GetString(clear)); }
            finally { Array.Clear(clear, 0, clear.Length); }
        }
        public static void Save(Credentials value) {
            Directory.CreateDirectory(Folder);
            byte[] clear = Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(value));
            try { File.WriteAllBytes(FilePath, ProtectedData.Protect(clear, Entropy, DataProtectionScope.CurrentUser)); }
            finally { Array.Clear(clear, 0, clear.Length); }
        }
        public static Credentials Import(string path) {
            string username = null, password = null;
            foreach (var line in File.ReadAllLines(path, Encoding.UTF8)) {
                if (line.StartsWith("用户名：")) username = line.Substring(4).Trim();
                if (line.StartsWith("密码：")) password = line.Substring(3).Trim();
            }
            if (String.IsNullOrEmpty(username) || String.IsNullOrEmpty(password) || username.Contains(":"))
                throw new InvalidOperationException("文件中没有找到有效的用户名和密码，请选择 Sunshine-管理凭据.txt。");
            var result = new Credentials { Username = username, Password = password, CertificateHash = LocalSunshine.CertificateHash() };
            new SunshineApi(result).Get("/api/pin"); // Verify before replacing the saved credentials.
            Save(result);
            return result;
        }
    }

    public sealed class PairingRequest {
        public string Id;
        public string Name;
        public string Address;
        public override string ToString() { return Name + "   ·   " + Address; }
    }
    public sealed class Snapshot {
        public List<PairingRequest> Pending;
        public int Clients;
        public string Endpoint;
    }
    public sealed class SunshineApi {
        readonly Credentials credentials;
        public readonly Uri BaseUri;
        public SunshineApi(Credentials credentials) {
            if (credentials == null || String.IsNullOrEmpty(credentials.Password) || !Regex.IsMatch(credentials.CertificateHash ?? "", "^[0-9A-Fa-f]{64}$"))
                throw new InvalidOperationException("保存的管理凭据无效，请重新导入。");
            this.credentials = credentials;
            BaseUri = LocalSunshine.Endpoint();
        }
        public static bool ValidPin(string value) { return Regex.IsMatch(value ?? "", "^[0-9]{4}$"); }
        public Dictionary<string, object> Get(string path) { return Call(path, null, null, 5000); }
        Dictionary<string, object> Call(string path, object body, string csrf, int timeout) {
            if (!new[] { "/api/pin", "/api/csrf-token", "/api/clients/list" }.Contains(path)) throw new InvalidOperationException("Unsupported endpoint.");
            if (!LocalSunshine.IsLocalAddress(BaseUri.Host)) throw new InvalidOperationException("仅允许连接本机 Sunshine。");
            var request = (HttpWebRequest)WebRequest.Create(new Uri(BaseUri, path));
            request.Proxy = null;
            request.AllowAutoRedirect = false;
            request.KeepAlive = false;
            request.ConnectionGroupName = credentials.CertificateHash;
            request.Timeout = timeout;
            request.ReadWriteTimeout = timeout;
            request.Method = body == null ? "GET" : "POST";
            request.Accept = "application/json";
            request.ServerCertificateValidationCallback = delegate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
                return certificate != null && String.Equals(LocalSunshine.Hash(certificate.GetRawCertData()), credentials.CertificateHash, StringComparison.OrdinalIgnoreCase);
            };
            request.Headers[HttpRequestHeader.Authorization] = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes(credentials.Username + ":" + credentials.Password));
            if (csrf != null) request.Headers["X-CSRF-Token"] = csrf;
            if (body != null) {
                byte[] payload = Encoding.UTF8.GetBytes(new JavaScriptSerializer().Serialize(body));
                request.ContentType = "application/json";
                request.ContentLength = payload.Length;
                using (var stream = request.GetRequestStream()) stream.Write(payload, 0, payload.Length);
            }
            try {
                using (var response = (HttpWebResponse)request.GetResponse()) {
                    if (response.StatusCode != HttpStatusCode.OK) throw new InvalidOperationException("Sunshine 返回异常状态，请检查管理入口。");
                    using (var reader = new StreamReader(response.GetResponseStream(), Encoding.UTF8))
                        return new JavaScriptSerializer().Deserialize<Dictionary<string, object>>(reader.ReadToEnd());
                }
            } catch (WebException e) {
                var failed = e.Response as HttpWebResponse;
                if (failed == null) throw;
                int code = (int)failed.StatusCode;
                failed.Dispose();
                if (code == 401) throw new InvalidOperationException("管理凭据已失效，请重新导入。");
                if (code == 403) throw new InvalidOperationException("Sunshine 拒绝了本机管理访问，请检查管理入口设置。");
                throw new InvalidOperationException("Sunshine 请求未完成（HTTP " + code + "），请刷新后重试。");
            }
        }
        public static IEnumerable<Dictionary<string, object>> Rows(Dictionary<string, object> value, string key) {
            object rows;
            if (!value.TryGetValue(key, out rows) || !(rows is IEnumerable) || rows is string) throw new InvalidOperationException("Sunshine 接口返回的列表格式不正确。");
            foreach (var row in (IEnumerable)rows) {
                var item = row as Dictionary<string, object>;
                if (item == null) throw new InvalidOperationException("Sunshine 接口返回的设备格式不正确。");
                yield return item;
            }
        }
        public Snapshot Read() {
            var pending = Rows(Get("/api/pin"), "pairings").Select(p => new PairingRequest {
                Id = Convert.ToString(p["id"]), Name = Convert.ToString(p["name"]), Address = Convert.ToString(p["address"])
            }).ToList();
            return new Snapshot { Pending = pending, Clients = Rows(Get("/api/clients/list"), "named_certs").Count(), Endpoint = BaseUri.ToString() };
        }
        public bool Pair(PairingRequest pairing, string pin) {
            if (!ValidPin(pin)) throw new InvalidOperationException("请输入手机上显示的 4 位数字 PIN。");
            if (pairing == null || !Regex.IsMatch(pairing.Id ?? "", "^[a-fA-F0-9]{32}$")) throw new InvalidOperationException("请先选择待配对设备。");
            var active = Rows(Get("/api/pin"), "pairings").Any(p => Convert.ToString(p["id"]) == pairing.Id);
            if (!active) throw new InvalidOperationException("这次配对请求已经结束，请在手机重新开始配对。");
            string token = Convert.ToString(Get("/api/csrf-token")["csrf_token"]);
            string name = String.IsNullOrWhiteSpace(pairing.Name) ? "Moonlight 手机" : pairing.Name;
            if (Encoding.UTF8.GetByteCount(name) > 128) name = "Moonlight 手机";
            var result = Call("/api/pin", new { pairing_id = pairing.Id, pin = pin, name = name }, token, 40000);
            object status;
            return result.TryGetValue("status", out status) && status is bool && (bool)status;
        }
    }

    public sealed class PairingForm : Form {
        readonly Color ink = Color.FromArgb(23, 39, 58), teal = Color.FromArgb(0, 119, 110);
        readonly Label connection = new Label(), note = new Label(), footer = new Label();
        readonly ComboBox devices = new ComboBox();
        readonly TextBox pin = new TextBox();
        readonly Button submit = new Button(), refresh = new Button(), import = new Button();
        readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        bool reading, pairing, closed, connected, sticky;
        int clients;

        public PairingForm() {
            Text = "Sunshine 配对工具";
            Font = new Font("Microsoft YaHei UI", 10F);
            AutoScaleMode = AutoScaleMode.Font;
            AutoScaleDimensions = CurrentAutoScaleDimensions;
            ClientSize = new Size(720, 650);
            BackColor = Color.FromArgb(243, 246, 248);
            ForeColor = ink;
            StartPosition = FormStartPosition.CenterScreen;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

            var header = new Panel { Dock = DockStyle.Top, Height = 104, BackColor = ink };
            header.Controls.Add(LabelAt("Sunshine 配对", 24, 15, 650, 40, 23, true, Color.White));
            header.Controls.Add(LabelAt("让手机连接这台电脑", 26, 62, 640, 24, 11, false, Color.FromArgb(185, 209, 217)));
            Controls.Add(header);
            connection.SetBounds(24, 124, 672, 40);
            connection.Text = "正在连接 Sunshine…";
            connection.BackColor = Color.FromArgb(227, 240, 238);
            connection.ForeColor = teal;
            connection.TextAlign = ContentAlignment.MiddleLeft;
            connection.Padding = new Padding(12, 0, 0, 0);
            Controls.Add(connection);

            var card = new Panel { Location = new Point(24, 184), Size = new Size(672, 350), BackColor = Color.White };
            card.Controls.Add(LabelAt("待配对设备", 24, 16, 620, 25, 10, true, ink));
            devices.SetBounds(24, 48, 520, 32);
            devices.DropDownStyle = ComboBoxStyle.DropDownList;
            devices.AccessibleName = "待配对设备";
            devices.SelectedIndexChanged += delegate { pin.Clear(); UpdateSubmit(); };
            card.Controls.Add(devices);
            StyleButton(refresh, "刷新", 558, 45, 90, 34, false);
            refresh.Click += async delegate { sticky = false; await RefreshAsync(); };
            card.Controls.Add(refresh);
            card.Controls.Add(LabelAt("手机上显示的 4 位 PIN", 24, 100, 620, 25, 10, true, ink));
            pin.SetBounds(24, 133, 624, 68);
            pin.Font = new Font("Consolas", 34F, FontStyle.Bold);
            pin.TextAlign = HorizontalAlignment.Center;
            pin.MaxLength = 4;
            pin.BorderStyle = BorderStyle.FixedSingle;
            pin.AccessibleName = "手机配对 PIN";
            pin.TextChanged += delegate { UpdateSubmit(); };
            pin.KeyPress += delegate(object sender, KeyPressEventArgs e) { if (!Char.IsControl(e.KeyChar) && (e.KeyChar < '0' || e.KeyChar > '9')) e.Handled = true; };
            card.Controls.Add(pin);
            StyleButton(submit, "完成配对", 24, 218, 624, 49, true);
            submit.Enabled = false;
            submit.Click += async delegate { await PairAsync(); };
            card.Controls.Add(submit);
            note.SetBounds(24, 284, 624, 54);
            note.ForeColor = Color.FromArgb(95, 109, 122);
            note.Text = "先在手机 Moonlight 中点击电脑，\r\n出现 PIN 后，待配对设备会自动显示在这里。";
            card.Controls.Add(note);
            Controls.Add(card);
            Controls.Add(LabelAt("手机打开 Moonlight → 点击电脑 → 保持 PIN 页面亮屏", 24, 553, 672, 27, 10, false, Color.FromArgb(83, 99, 111)));
            footer.SetBounds(24, 605, 480, 26);
            footer.Font = new Font(Font.FontFamily, 9F);
            footer.ForeColor = Color.FromArgb(107, 119, 130);
            footer.Text = "本机连接 · PIN 不会保存";
            Controls.Add(footer);
            StyleButton(import, "导入管理凭据", 542, 599, 154, 34, false);
            import.Click += async delegate { await ImportAsync(); };
            Controls.Add(import);
            AcceptButton = submit;
            timer.Interval = 3000;
            timer.Tick += async delegate { await RefreshAsync(); };
            Shown += async delegate { timer.Start(); await RefreshAsync(); };
            FormClosed += delegate { closed = true; timer.Stop(); timer.Dispose(); pin.Clear(); };
        }
        Label LabelAt(string text, int x, int y, int w, int h, float size, bool bold, Color color) {
            return new Label { Text = text, Location = new Point(x, y), Size = new Size(w, h), ForeColor = color,
                Font = new Font("Microsoft YaHei UI", size, bold ? FontStyle.Bold : FontStyle.Regular), AutoEllipsis = true };
        }
        void StyleButton(Button button, string text, int x, int y, int w, int h, bool primary) {
            button.Text = text; button.SetBounds(x, y, w, h); button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = primary ? 0 : 1;
            button.FlatAppearance.BorderColor = Color.FromArgb(211, 221, 225);
            button.BackColor = primary ? teal : Color.White;
            button.ForeColor = primary ? Color.White : ink;
            button.Font = new Font("Microsoft YaHei UI", primary ? 12F : 9F, primary ? FontStyle.Bold : FontStyle.Regular);
            button.Cursor = Cursors.Hand;
        }
        void UpdateSubmit() {
            submit.Enabled = connected && !reading && !pairing && devices.SelectedItem is PairingRequest && SunshineApi.ValidPin(pin.Text);
            submit.BackColor = submit.Enabled ? teal : Color.FromArgb(221, 229, 231);
        }
        void SetNote(string text, bool error) { note.Text = text; note.ForeColor = error ? Color.FromArgb(170, 55, 41) : teal; }
        static string Explain(Exception e) {
            var web = e as WebException;
            if (web != null) {
                var response = web.Response as HttpWebResponse;
                if (response != null && response.StatusCode == HttpStatusCode.Unauthorized) return "管理凭据已失效，请重新导入。";
                if (web.Status == WebExceptionStatus.TrustFailure || web.Status == WebExceptionStatus.SecureChannelFailure)
                    return "Sunshine 证书校验未通过。确认本机安装后，请重新导入管理凭据。";
                if (web.Status == WebExceptionStatus.Timeout) return "请求超时，结果尚未确认。请查看手机状态；不要重复提交旧 PIN。";
                return "无法连接本机 Sunshine，请确认 Sunshine 正在运行，再点击刷新。";
            }
            if (e is CryptographicException) return "无法解密管理凭据，请用当前 Windows 账户重新导入。";
            if (e is IOException || e is UnauthorizedAccessException) return "无法读取本机 Sunshine 配置或凭据文件。";
            return e is InvalidOperationException ? e.Message : "操作未完成，请刷新重试或重新导入管理凭据。";
        }
        async Task RefreshAsync() {
            if (reading || pairing || closed) return;
            reading = true; UpdateSubmit();
            try {
                var snapshot = await Task.Run(() => new SunshineApi(Vault.Load()).Read());
                if (closed) return;
                connected = true; clients = snapshot.Clients;
                string selected = devices.SelectedItem is PairingRequest ? ((PairingRequest)devices.SelectedItem).Id : null;
                string oldIds = String.Join(",", devices.Items.Cast<PairingRequest>().Select(p => p.Id));
                string newIds = String.Join(",", snapshot.Pending.Select(p => p.Id));
                if (oldIds != newIds) {
                    pin.Clear();
                    devices.Items.Clear();
                    foreach (var item in snapshot.Pending) devices.Items.Add(item);
                    var previous = snapshot.Pending.Find(p => p.Id == selected);
                    if (previous != null) devices.SelectedItem = previous;
                    else if (snapshot.Pending.Count == 1) devices.SelectedIndex = 0;
                    else devices.SelectedIndex = -1;
                    if (snapshot.Pending.Count > 0) sticky = false;
                }
                connection.Text = "已连接 Sunshine  ·  " + snapshot.Endpoint.TrimEnd('/');
                connection.ForeColor = teal;
                footer.Text = "已配对设备：" + clients + "  ·  PIN 不会保存";
                if (!sticky) {
                    if (snapshot.Pending.Count == 0) SetNote("还没有待配对请求。请先在手机 Moonlight 中点击电脑。", false);
                    else if (snapshot.Pending.Count == 1) SetNote("已发现手机请求。输入手机当前显示的 PIN，保持手机亮屏。", false);
                    else SetNote("发现多个请求。请核对设备名和来源地址，选择正确设备。", false);
                }
            } catch (Exception e) {
                if (closed) return;
                connected = false;
                connection.Text = "暂未连接 Sunshine";
                connection.ForeColor = Color.FromArgb(170, 55, 41);
                SetNote(Explain(e), true);
            } finally { reading = false; if (!closed) UpdateSubmit(); }
        }
        async Task PairAsync() {
            if (!submit.Enabled || pairing) return;
            var target = devices.SelectedItem as PairingRequest;
            string value = pin.Text;
            pairing = true; timer.Stop();
            submit.Text = "正在等待手机…";
            pin.Enabled = devices.Enabled = refresh.Enabled = import.Enabled = false;
            UpdateSubmit();
            SetNote("正在完成配对握手，请保持手机停留在 PIN 页面。", false);
            try {
                bool ok = await Task.Run(() => new SunshineApi(Vault.Load()).Pair(target, value));
                if (closed) return;
                sticky = true;
                SetNote(ok ? "配对成功！现在可以在手机点击 Desktop 进入电脑桌面。" : "配对未完成。请在手机重新发起配对，再输入新的 PIN。", !ok);
            } catch (Exception e) { if (!closed) { sticky = true; SetNote(Explain(e), true); } }
            finally {
                value = null;
                pairing = false;
                if (!closed) {
                    pin.Clear(); pin.Enabled = devices.Enabled = refresh.Enabled = import.Enabled = true;
                    submit.Text = "完成配对"; timer.Start();
                }
            }
            if (!closed) await RefreshAsync();
        }
        async Task ImportAsync() {
            if (reading || pairing) return;
            using (var dialog = new OpenFileDialog { Title = "选择 Sunshine-管理凭据.txt", Filter = "管理凭据文件 (*.txt)|*.txt", CheckFileExists = true }) {
                if (dialog.ShowDialog(this) != DialogResult.OK) return;
                reading = true; import.Enabled = refresh.Enabled = false; UpdateSubmit();
                try { await Task.Run(() => Vault.Import(dialog.FileName)); if (!closed) sticky = false; }
                catch (Exception e) { if (!closed) { SetNote(Explain(e), true); sticky = true; } }
                finally { reading = false; if (!closed) import.Enabled = refresh.Enabled = true; }
            }
            if (!closed) await RefreshAsync();
        }
    }

    public static class Program {
        [STAThread]
        public static int Main(string[] args) {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            if (args.Length == 3 && args[0] == "--bootstrap") {
                try { Vault.Import(args[1]); File.WriteAllText(args[2], "Credentials imported and local TLS/API verified."); return 0; }
                catch (Exception e) { File.WriteAllText(args[2], "Bootstrap failed: " + e.GetType().Name + ": " + e.Message); return 1; }
            }
            if (args.Length == 2 && args[0] == "--verify") {
                var results = new Dictionary<string, object>();
                try {
                    var credentials = Vault.Load();
                    var snapshot = new SunshineApi(credentials).Read();
                    results["liveApi"] = true; results["pendingRequests"] = snapshot.Pending.Count; results["pairedDevices"] = snapshot.Clients;
                    results["localOnly"] = !LocalSunshine.IsLocalAddress("203.0.113.1") && !LocalSunshine.IsLocalAddress("example.com");
                    results["leadingZeroPin"] = SunshineApi.ValidPin("0001");
                    var invalid = new Credentials { Username = credentials.Username, Password = credentials.Password, CertificateHash = new string('0', 64) };
                    bool refused = false;
                    try { new SunshineApi(invalid).Get("/api/pin"); } catch (WebException) { refused = true; }
                    results["wrongCertificateRefused"] = refused;
                    byte[] clear = Encoding.UTF8.GetBytes(credentials.Password);
                    byte[] vault = File.ReadAllBytes(Vault.FilePath);
                    results["vaultContainsPlainPassword"] = Encoding.UTF8.GetString(vault).Contains(credentials.Password);
                    Array.Clear(clear, 0, clear.Length);
                    File.WriteAllText(args[1], new JavaScriptSerializer().Serialize(results), Encoding.UTF8);
                    return refused ? 0 : 2;
                } catch { results["liveApi"] = false; File.WriteAllText(args[1], new JavaScriptSerializer().Serialize(results), Encoding.UTF8); return 1; }
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new PairingForm());
            return 0;
        }
    }
}
