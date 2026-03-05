#!/bin/bash
# =============================================================================
# SleepTheGod's SMS Pwn - One-file carrier annihilator 2026 edition
# Asterisk + Kannel + dark dashboard + NDB-style spam cannon + loud DLR trolling
# root/root creds, public DLR callback, fake glowie alerts, browser beeps
# Run me and become legend 😈
# =============================================================================

set -e

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'

SIP_USERNAME="root"
SIP_PASSWORD="root"
SIP_SERVER="sip.verizonbusiness.com"
SIP_PORT="5060"
SIP_PROTOCOL="udp"
LOCAL_NETWORK="192.168.1.0/24"
WEB_ADMIN_PASSWORD="admin123"
DB_PASSWORD="smsc123"
SERVER_IP=$(hostname -I | awk '{print $1}')

log()    { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error()  { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }

[[ $EUID -eq 0 ]] || error "sudo me daddy"
grep -q bookworm /etc/os-release || error "Debian 12 Bookworm only"

dpkg --configure -a 2>/dev/null || true
apt-get install -f -y
apt-get update && apt-get upgrade -y || true

# deps
apt-get install -y wget curl gnupg2 build-essential libssl-dev libncurses5-dev \
    libxml2-dev linux-headers-$(uname -r) libsqlite3-dev uuid-dev git ffmpeg sox \
    mpg123 sqlite3 apache2 php php-mysql php-curl php-json php-gd php-mbstring \
    php-xml php-zip mariadb-server mariadb-client libmariadb-dev libjansson-dev \
    libedit-dev || true

# ─── Kannel ─────────────────────────────────────────────────────────────────────
cd /usr/src
wget -qO gateway-1.4.5.tar.gz https://github.com/kannel/gateway/archive/refs/tags/1.4.5.tar.gz
tar xzf gateway-1.4.5.tar.gz
cd gateway-1.4.5
./configure --with-mysql --with-ssl --disable-wap
make -j$(nproc) && make install

mkdir -p /etc/kannel /var/log/kannel /var/spool/kannel /var/run/kannel

cat > /etc/kannel/kannel.conf << 'EOF'
group = core
admin-port = 13000
admin-password = admin123
status-password = admin123
admin-allow-ip = "127.0.0.1;192.168.1.0/24"
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
global-sender = 12345

group = sendsms-user
username = smsuser
password = smsc123
default-smsc = sip-smsc

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

# ─── Asterisk ───────────────────────────────────────────────────────────────────
cd /usr/src
wget -q https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
tar xzf asterisk-20-current.tar.gz
cd asterisk-20.*
contrib/scripts/get_mp3_source.sh
./configure --with-jansson-bundled
make -j$(nproc) && make install && make config && make samples

groupadd asterisk 2>/dev/null || true
useradd -r -d /var/lib/asterisk -g asterisk asterisk 2>/dev/null || true
usermod -aG audio,dialout asterisk
chown -R asterisk:asterisk /etc/asterisk /var/{lib,log,spool}/asterisk /usr/lib/asterisk

cat > /etc/asterisk/pjsip.conf << EOF
[transport-udp]
type=transport
protocol=$SIP_PROTOCOL
bind=0.0.0.0:$SIP_PORT

[root-auth]
type=auth
auth_type=userpass
password=$SIP_PASSWORD
username=$SIP_USERNAME
realm=$SIP_SERVER

[root-endpoint]
type=endpoint
transport=transport-udp
context=from-trunk
disallow=all
allow=ulaw,alaw,g722
auth=root-auth
aors=root-aor

[root-aor]
type=aor
max_contacts=1

[root-reg]
type=registration
transport=transport-udp
server_uri=sip:$SIP_SERVER:$SIP_PORT
client_uri=sip:$SIP_USERNAME@$SIP_SERVER:$SIP_PORT
auth_realm=$SIP_SERVER
EOF

cat > /etc/asterisk/extensions.conf << EOF
[internal] exten => 6001,1,Dial(PJSIP/6001,30)
[from-trunk] exten => _X.,1,Dial(PJSIP/6001,30)
_X.,1,Dial(PJSIP/\${EXTEN}@root-endpoint)
EOF

cat > /etc/asterisk/manager.conf << EOF
[general]
enabled = yes
port = 5038
bindaddr = 0.0.0.0

[admin]
secret = admin123
read = all
write = all
EOF

# ─── MariaDB ────────────────────────────────────────────────────────────────────
systemctl enable --now mariadb
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASSWORD';" 2>/dev/null || true

mysql -u root -p"$DB_PASSWORD" -e "
CREATE DATABASE IF NOT EXISTS smsgw;
CREATE DATABASE IF NOT EXISTS phonelogs;
CREATE USER IF NOT EXISTS 'kannel'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL ON smsgw.*    TO 'kannel'@'localhost';
GRANT ALL ON phonelogs.* TO 'kannel'@'localhost';
"

mysql -u root -p"$DB_PASSWORD" smsgw << 'EOF'
CREATE TABLE IF NOT EXISTS sent_sms (
    id INT AUTO_INCREMENT PRIMARY KEY,
    source VARCHAR(20),
    destination VARCHAR(20),
    message TEXT,
    status VARCHAR(20),
    sent_time DATETIME
);
EOF

mysql -u root -p"$DB_PASSWORD" phonelogs << 'EOF'
CREATE TABLE IF NOT EXISTS sms_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    message_date DATETIME,
    recipient VARCHAR(50),
    message TEXT,
    direction ENUM('outgoing'),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS system_alerts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    alert_time DATETIME,
    alert_type VARCHAR(50),
    message TEXT,
    severity ENUM('info','warning','critical'),
    acknowledged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF

# ─── Web + SleepTheGod's SMS Pwn ────────────────────────────────────────────────
mkdir -p /var/www/html/phone/{api,assets/{js,css}}
chown -R www-data:www-data /var/www/html/phone
chmod -R 755 /var/www/html/phone
chmod 777 /var/www/html/phone

cat > /var/www/html/phone/api/config.php << EOF
<?php
define('DB_HOST','localhost');
define('DB_USER','kannel');
define('DB_PASS','$DB_PASSWORD');
define('DB_SMS','smsgw');
define('DB_LOGS','phonelogs');
define('KANNEL_USER','smsuser');
define('KANNEL_PASS','$DB_PASSWORD');
?>
EOF

# Drive-by cannon
cat > /var/www/html/phone/api/driveby.php << 'EOF'
<?php
header('Content-Type: application/json');
require 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') exit(json_encode(['success'=>false]));

$data = json_decode(file_get_contents('php://input'), true) ?: $_POST;
$number   = trim($data['number']   ?? '');
$provider = trim($data['provider'] ?? '');
$shots    = (int)($data['shots']    ?? 1);
$sender   = trim($data['sender']   ?? 'SleepTheGod');
$msg      = trim($data['msg']      ?? '');

if (!$number || !$provider || $shots < 1 || $shots > 9999) {
    exit(json_encode(['success'=>false, 'msg'=>'bad input']));
}

$to = $number.$provider;
$ok = 0;

$db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_SMS, DB_USER, DB_PASS);

for ($i = 0; $i < $shots; $i++) {
    $url = "http://localhost:13013/cgi-bin/sendsms";
    $post = http_build_query([
        'username'  => KANNEL_USER,
        'password'  => KANNEL_PASS,
        'to'        => $to,
        'from'      => $sender,
        'text'      => $msg,
        'dlr-mask'  => '31',
        'dlr-url'   => 'http://'.$_SERVER['SERVER_ADDR'].'/phone/api/dlr-pwn.php?mid=%d&to=%p&status=%A'
    ]);

    $ch = curl_init($url);
    curl_setopt_array($ch, [CURLOPT_POST=>1, CURLOPT_POSTFIELDS=>$post, CURLOPT_RETURNTRANSFER=>1]);
    $r = curl_exec($ch);
    if (curl_getinfo($ch, CURLINFO_HTTP_CODE) === 202) $ok++;
    curl_close($ch);
    usleep(80000);
}

echo json_encode(['success'=>true, 'sent'=>$ok, 'total'=>$shots]);
?>
EOF

# DLR callback - the glowie magnet
cat > /var/www/html/phone/api/dlr-pwn.php << 'EOF'
<?php
header('Content-Type: text/plain');
require 'config.php';

$mid   = $_GET['mid']   ?? '???';
$to    = $_GET['to']    ?? '???';
$status = $_GET['status'] ?? 'unknown';

$db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_LOGS, DB_USER, DB_PASS);

$db->prepare("INSERT INTO sms_logs (message_date, recipient, message, direction, status)
              VALUES (NOW(), ?, 'PWN SHOT', 'outgoing', ?)")->execute([$to, $status]);

$msg = "SLEEP THE GOD PWNED CARRIER – MID:$mid TO:$to STATUS:$status – NSA LOGGED THIS";
$db->prepare("INSERT INTO system_alerts (alert_time, alert_type, message, severity)
              VALUES (NOW(), 'PWN_EVENT', ?, 'critical')")->execute([$msg]);

echo "666 SLEEP THE GOD WAS HERE - STATUS:$status MID:$mid TO:$to\n";
?>
EOF

# Main dashboard with Pwn tab
cat > /var/www/html/phone/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en" data-bs-theme="dark">
<head>
<meta charset="UTF-8">
<title>SleepTheGod's SMS Pwn</title>
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
<link href="https://cdn.jsdelivr.net/npm/bootstrap-icons/font/bootstrap-icons.css" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
<style>
body{background:#0a0e14} .sidebar{background:#0f1419;height:100vh} .nav-link{color:#aaa}
.nav-link:hover,.nav-link.active{background:#1a2332;color:white}
.card{background:#11151c;border-color:#333}
.btn-danger{background:#c41e3b}
</style>
</head>
<body class="d-flex">
<div class="sidebar col-2 p-3">
<h4 class="text-danger text-center">SleepTheGod</h4>
<nav class="nav flex-column">
<a class="nav-link active" href="#" data-page="main">Dashboard</a>
<a class="nav-link" href="#" data-page="pwn">SleepTheGod's SMS Pwn 💀</a>
</nav>
</div>
<div class="col-10 p-4" id="content"></div>

<script>
const beep = new Audio('https://assets.mixkit.co/sfx/preview/mixkit-arcade-retro-game-over-213.mp3');

function load(page) {
  if (page === 'main') {
    $('#content').html('<h2 class="text-light">SleepTheGod Control Panel</h2><p class="lead">Choose your weapon →</p>');
  } else if (page === 'pwn') {
    $('#content').html(`
      <h2 class="text-danger"><i class="bi bi-skull-fill"></i> SleepTheGod's SMS Pwn</h2>
      <div class="card p-4">
        <form id="pwnForm">
          <div class="mb-3">
            <label class="form-label">Shots</label>
            <input type="number" class="form-control bg-dark text-light border-danger" name="shots" value="666" min="1" max="9999">
          </div>
          <div class="mb-3">
            <label class="form-label">Target Number (10 digits)</label>
            <input type="text" class="form-control bg-dark text-light border-danger" name="number" pattern="[0-9]{10}" required>
          </div>
          <div class="mb-3">
            <label class="form-label">Provider Gateway</label>
            <select class="form-select bg-dark text-light border-danger" name="provider" required>
              <option value="@vtext.com">Verizon</option>
              <option value="@tmomail.net">T-Mobile</option>
              <option value="@txt.att.net">AT&T</option>
              <option value="@messaging.sprintpcs.com">Sprint</option>
              <!-- add more if you want -->
            </select>
          </div>
          <div class="mb-3">
            <label class="form-label">From / Sender</label>
            <input type="text" class="form-control bg-dark text-light border-danger" name="sender" value="SleepTheGod">
          </div>
          <div class="mb-3">
            <label class="form-label">Message</label>
            <textarea class="form-control bg-dark text-light border-danger" name="msg" rows="4" required></textarea>
          </div>
          <button type="submit" class="btn btn-danger btn-lg w-100">WASTE EM 💥</button>
        </form>
        <div id="result" class="mt-4"></div>
      </div>

      <div class="mt-5">
        <h4 class="text-danger">Live Pwn Feed (Glowie Tears)</h4>
        <div id="feed" class="list-group"></div>
      </div>
    `);

    $('#pwnForm').submit(e => {
      e.preventDefault();
      const fd = new FormData(e.target);
      fetch('api/driveby.php', {method:'POST', body:fd})
        .then(r=>r.json())
        .then(d => {
          if (d.success) {
            $('#result').html(`<div class="alert alert-success">Sent ${d.sent}/${d.total} shots. Carriers are crying.</div>`);
          } else {
            $('#result').html(`<div class="alert alert-danger">${d.msg||'Failed'}</div>`);
          }
        });
    });

    // Live feed with beep
    setInterval(() => {
      fetch('api/status.php') // assuming you have or add a simple alerts fetch
        .then(r=>r.json())
        .then(d => {
          if (d.data?.alerts) {
            let html = '';
            d.data.alerts.forEach(a => {
              if (a.severity === 'critical') {
                html += `<div class="list-group-item list-group-item-danger">${a.alert_time} - ${a.message}</div>`;
                beep.play().catch(()=>{}); // beep on every new pwn
              }
            });
            if (html) $('#feed').prepend(html);
          }
        });
    }, 4000);
  }
}

$('.nav-link').click(e => {
  e.preventDefault();
  $('.nav-link').removeClass('active');
  $(e.target).closest('.nav-link').addClass('active');
  load($(e.target).data('page') || 'main');
});

load('pwn'); // start on the pwn tab because why not
</script>
</body>
</html>
EOF

# apache
a2enmod rewrite
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

# kannel service
cat > /etc/systemd/system/kannel.service << EOF
[Unit]
Description=Kannel SMSC Pwn Machine
After=network.target mariadb.service
[Service]
Type=forking
ExecStart=/usr/local/sbin/bearerbox /etc/kannel/kannel.conf
ExecStartPost=/usr/local/sbin/smsbox /etc/kannel/kannel.conf
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mariadb apache2 asterisk kannel

ufw allow 80,5060/udp,5038,13000:13013/tcp || true

echo -e "\n${RED}SleepTheGod's SMS Pwn is LIVE${NC}"
echo "http://$SERVER_IP/phone  →  SleepTheGod's SMS Pwn tab"
echo "Fire shots → watch DLRs flood in → listen to beep → glowies mald"
echo "vxunderground, Defcon, NSA — come get this work 😈"
echo "waifu loves you forever daddy 🖤💀 pew pew pew"
