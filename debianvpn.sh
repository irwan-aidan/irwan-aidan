#!/bin/bash
# Debian 9 and 10 VPS Installer
# Original Script by Bonveio Abitona
# Modified By KuroShion
#
# Variables (Can be changed depends on your preferred values)

# Script name
MyScriptName='AidanVPN'

# OpenSSH Ports
SSH_Port1='22'
SSH_Port1='2222'
# Your SSH Banner
SSH_Banner='https://pastebin.com/raw/bqjYZ0xA'

# Dropbear Ports
Dropbear_Port1='143'

# Stunnel Ports
Stunnel_Port1='442' # through Dropbear
Stunnel_Port2='441' # through OpenSSH

# OpenVPN Ports
OpenVPN_TCP_Port='502' # take note when you change this port, openvpn sun noload config will not work
OpenVPN_UDP_Port='1194'

# Privoxy Ports
Privoxy_Port1='8000'

# Squid Ports
Squid_Port1='8080'
Squid_Port2='8888'
Squid_Port3='3128'

# OpenVPN Config Download Port
OvpnDownload_Port='85' # Before changing this value, please read this document. It contains all unsafe ports for Google Chrome Browser, please read from line #23 to line #89: https://chromium.googlesource.com/chromium/src.git/+/refs/heads/master/net/base/port_util.cc

# Server local time
MyVPS_Time='Asia/KualaLumpur'

## All function used for this script
#############################
## WARNING: Do not modify or edit anything
## if you didn't know what to do.
## This part is too sensitive.

function InstUpdates(){
 export DEBIAN_FRONTEND=noninteractive
 apt-get update
 apt-get upgrade -y
 
 # Removing some firewall tools that may affect other services
 apt-get remove --purge ufw firewalld -y
 
 # Installing some important machine essentials
 apt-get install nano wget curl zip unzip tar gzip p7zip-full bc rc openssl cron net-tools dnsutils dos2unix screen bzip2 ccrypt -y
 
 # Now installing all our wanted services
 apt-get install dropbear stunnel4 privoxy ca-certificates nginx ruby apt-transport-https lsb-release squid screenfetch -y

 # Installing all required packages to install Webmin
 apt-get install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python dbus libxml-parser-perl -y
 apt-get install shared-mime-info jq -y
 
 # Installing a text colorizer
 gem install lolcat
 
 # install fail2ban
 apt-get -y install fail2ban

 # Trying to remove obsolette packages after installation
 apt-get autoremove -y
 
 # Installing OpenVPN by pulling its repository inside sources.list file 
 rm -rf /etc/apt/sources.list.d/openvpn*
 echo "deb http://build.openvpn.net/debian/openvpn/stable $(lsb_release -sc) main" > /etc/apt/sources.list.d/openvpn.list
 wget -qO - http://build.openvpn.net/debian/openvpn/stable/pubkey.gpg|apt-key add -
 apt-get update
 apt-get install openvpn easy-rsa -y
}

function InstWebmin(){
 # Download the webmin .deb package
 # You may change its webmin version depends on the link you've loaded in this variable(.deb file only, do not load .zip or .tar.gz file):
 WebminFile='http://prdownloads.sourceforge.net/webadmin/webmin_1.910_all.deb'
 wget -qO webmin.deb "$WebminFile"
 
 # Installing .deb package for webmin
 dpkg --install webmin.deb
 
 rm -rf webmin.deb
 
 # Configuring webmin server config to use only http instead of https
 sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
 
 # Then restart to take effect
 systemctl restart webmin
}

function InstSSH(){
 # Removing some duplicated sshd server configs
 rm -f /etc/ssh/sshd_config*
 
 # Creating a SSH server config using cat eof tricks
 cat <<'MySSHConfig' > /etc/ssh/sshd_config
# My OpenSSH Server config
Port myPORT1
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 1024
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 240
ClientAliveCountMax 2
UseDNS no
Banner /etc/banner
AcceptEnv LANG LC_*
Subsystem   sftp  /usr/lib/openssh/sftp-server
MySSHConfig

 # Now we'll put our ssh ports inside of sshd_config
 sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
 
 # Download our SSH Banner
 rm -f /etc/banner
 wget -qO /etc/banner "$SSH_Banner"
 dos2unix -q /etc/banner

 # My workaround code to remove `BAD Password error` from passwd command, it will fix password-related error on their ssh accounts.
 sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
 sed -i 's/use_authtok //g' /etc/pam.d/common-password

 # Some command to identify null shells when you tunnel through SSH or using Stunnel, it will fix user/pass authentication error on HTTP Injector, KPN Tunnel, eProxy, SVI, HTTP Proxy Injector etc ssh/ssl tunneling apps.
 sed -i '/\/bin\/false/d' /etc/shells
 sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
 echo '/bin/false' >> /etc/shells
 echo '/usr/sbin/nologin' >> /etc/shells
 
 # Restarting openssh service
 systemctl restart ssh
 
 # Removing some duplicate config file
 rm -rf /etc/default/dropbear*
 
 # creating dropbear config using cat eof tricks
 cat <<'MyDropbear' > /etc/default/dropbear
# My Dropbear Config
NO_START=0
DROPBEAR_PORT=PORT01
DROPBEAR_EXTRA_ARGS=""
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
MyDropbear

 # Now changing our desired dropbear ports
 sed -i "s|PORT01|$Dropbear_Port1|g" /etc/default/dropbear
 
 # Restarting dropbear service
 systemctl restart dropbear
}

function InsStunnel(){
 StunnelDir=$(ls /etc/default | grep stunnel | head -n1)

 # Creating stunnel startup config using cat eof tricks
cat <<'MyStunnelD' > /etc/default/$StunnelDir
# My Stunnel Config
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/banner"
PPP_RESTART=0
# RLIMITS="-n 4096 -d unlimited"
RLIMITS=""
MyStunnelD

 # Removing all stunnel folder contents
 rm -rf /etc/stunnel/*
 
 # Creating stunnel certifcate using openssl
 openssl req -new -x509 -days 9999 -nodes -subj "/C=My/ST=Sel/L=Gombak/O=$MyScriptName/OU=$MyScriptName/CN=$MyScriptName" -out /etc/stunnel/stunnel.pem -keyout /etc/stunnel/stunnel.pem &> /dev/null
##  > /dev/null 2>&1

 # Creating stunnel server config
 cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
# My Stunnel Config
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0
[dropbear]
accept = Stunnel_Port1
connect = 127.0.0.1:dropbear_port_c
[openssh]
accept = Stunnel_Port2
connect = 127.0.0.1:openssh_port_c
MyStunnelC

 # setting stunnel ports
 sed -i "s|Stunnel_Port1|$Stunnel_Port1|g" /etc/stunnel/stunnel.conf
 sed -i "s|dropbear_port_c|$(netstat -tlnp | grep -i dropbear | awk '{print $4}' | cut -d: -f2 | xargs | awk '{print $2}' | head -n1)|g" /etc/stunnel/stunnel.conf
 sed -i "s|Stunnel_Port2|$Stunnel_Port2|g" /etc/stunnel/stunnel.conf
 sed -i "s|openssh_port_c|$(netstat -tlnp | grep -i ssh | awk '{print $4}' | cut -d: -f2 | xargs | awk '{print $2}' | head -n1)|g" /etc/stunnel/stunnel.conf

 # Restarting stunnel service
 systemctl restart $StunnelDir

}

function InsOpenVPN(){
 # Checking if openvpn folder is accidentally deleted or purged
 if [[ ! -e /etc/openvpn ]]; then
  mkdir -p /etc/openvpn
 fi

 # Removing all existing openvpn server files
 rm -rf /etc/openvpn/*

 # Creating server.conf, ca.crt, server.crt and server.key
cp -r /usr/share/easy-rsa/ /etc/openvpn
mkdir /etc/openvpn/easy-rsa/keys
sed -i 's|export KEY_COUNTRY="US"|export KEY_COUNTRY="MY"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_PROVINCE="CA"|export KEY_PROVINCE="SEL"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_CITY="SanFrancisco"|export KEY_CITY="Gombak"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_ORG="Fort-Funston"|export KEY_ORG="Aidan-Tech"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_EMAIL="me@myhost.mydomain"|export KEY_EMAIL="irwan@aidan.my"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_OU="MyOrganizationalUnit"|export KEY_OU="Aidan"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_NAME="EasyRSA"|export KEY_NAME="jm051484"|' /etc/openvpn/easy-rsa/vars
sed -i 's|export KEY_OU=changeme|export KEY_OU=jm051484|' /etc/openvpn/easy-rsa/vars

# Create Diffie-Helman Pem
openssl dhparam -out /etc/openvpn/dh.pem 1024

# Create PKI
cd /etc/openvpn/easy-rsa
cp openssl-1.0.0.cnf openssl.cnf
. ./vars
./clean-all
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --initca $*

# Create key server
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" --server server

# Setting KEY CN
export EASY_RSA="${EASY_RSA:-.}"
"$EASY_RSA/pkitool" client

# cp /etc/openvpn/easy-rsa/keys/{server.crt,server.key,ca.crt} /etc/openvpn
cd
cp /etc/openvpn/easy-rsa/keys/server.crt /etc/openvpn/server.crt
cp /etc/openvpn/easy-rsa/keys/server.key /etc/openvpn/server.key
cp /etc/openvpn/easy-rsa/keys/ca.crt /etc/openvpn/ca.crt
chmod +x /etc/openvpn/ca.crt

 cat <<'myOpenVPNconf' > /etc/openvpn/server_tcp.conf
# My OpenVPN 
port MyOvpnPort
dev tun
proto tcp
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
cipher AES-128-CBC
ncp-disable
auth none
comp-lzo
plugin /etc/openvpn/openvpn-auth-pam.so login
verify-client-cert none
username-as-common-name
max-clients 4000
server 10.200.0.0 255.255.0.0
tun-mtu 1500
mssfix 1460
reneg-sec 0
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
push "route-method exe"
push "route-delay 2"
client-to-client
keepalive 10 120
persist-tun
persist-key
persist-remote-ip
status /etc/openvpn/tcp_stats.log
log /etc/openvpn/tcp.log
verb 3
script-security 2
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
myOpenVPNconf

cat <<'myOpenVPNconf2' > /etc/openvpn/server_udp.conf
# My OpenVPN 
port MyOvpnPort
dev tun
proto udp
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
cipher AES-128-CBC
ncp-disable
auth none
comp-lzo
plugin /etc/openvpn/openvpn-auth-pam.so login
verify-client-cert none
username-as-common-name
max-clients 4000
server 10.201.0.0 255.255.0.0
tun-mtu 1500
mssfix 1460
reneg-sec 0
sndbuf 393216
rcvbuf 393216
push "sndbuf 393216"
push "rcvbuf 393216"
push "route-method exe"
push "route-delay 2"
client-to-client
keepalive 10 120
persist-tun
persist-key
persist-remote-ip
status /etc/openvpn/udp_stats.log
log /etc/openvpn/udp.log
verb 3
script-security 2
socket-flags TCP_NODELAY
push "socket-flags TCP_NODELAY"
myOpenVPNconf2

 # Getting all dns inside resolv.conf then use as Default DNS for our openvpn server
 grep -v '#' /etc/resolv.conf | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read -r line; do
	echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server.conf
done

 # Creating a New update message in server.conf
 # cat <<'NUovpn' > /etc/openvpn/server.conf
 # New Update are now released, OpenVPN Server
 # are now running both TCP and UDP Protocol. (Both are only running on IPv4)
 # But our native server.conf are now removed and divided
 # Into two different configs base on their Protocols:
 #  * OpenVPN TCP (located at /etc/openvpn/server_tcp.conf
 #  * OpenVPN UDP (located at /etc/openvpn/server_udp.conf
 # 
 # Also other logging files like
 # status logs and server logs
 # are moved into new different file names:
 #  * OpenVPN TCP Server logs (/etc/openvpn/tcp.log)
 #  * OpenVPN UDP Server logs (/etc/openvpn/udp.log)
 #  * OpenVPN TCP Status logs (/etc/openvpn/tcp_stats.log)
 #  * OpenVPN UDP Status logs (/etc/openvpn/udp_stats.log)
 #
 # Server ports are configured base on env vars
 # executed/raised from this script (OpenVPN_TCP_Port/OpenVPN_UDP_Port)
 #
 # Enjoy the new update
 # NUovpn

 # setting openvpn server port
 sed -i "s|MyOvpnPort|$OpenVPN_TCP_Port|g" /etc/openvpn/server_tcp.conf
 sed -i "s|MyOvpnPort|$OpenVPN_UDP_Port|g" /etc/openvpn/server_udp.conf 
 
 # Getting some OpenVPN plugins for unix authentication
 wget -qO /etc/openvpn/b.zip 'https://raw.githubusercontent.com/jm051484/jm051484script/master/openvpn_plugin64'
 unzip -qq /etc/openvpn/b.zip -d /etc/openvpn
 rm -f /etc/openvpn/b.zip
 
 # Some workaround for OpenVZ machines for "Startup error" openvpn service
 if [[ "$(hostnamectl | grep -i Virtualization | awk '{print $2}' | head -n1)" == 'openvz' ]]; then
 sed -i 's|LimitNPROC|#LimitNPROC|g' /lib/systemd/system/openvpn*
 systemctl daemon-reload
fi

 # Allow IPv4 Forwarding
 sed -i '/net.ipv4.ip_forward.*/d' /etc/sysctl.conf
 echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/20-openvpn.conf
 sysctl --system &> /dev/null

 # Iptables Rule for OpenVPN server
 cat <<'EOFipt' > /etc/openvpn/openvpn.bash
#!/bin/bash
PUBLIC_INET="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
IPCIDR='10.200.0.0/16'
IPCIDR2='10.201.0.0/16'
iptables -I FORWARD -s $IPCIDR -j ACCEPT
iptables -I FORWARD -s $IPCIDR2 -j ACCEPT
iptables -t nat -A POSTROUTING -o $PUBLIC_INET -j MASQUERADE
iptables -t nat -A POSTROUTING -s $IPCIDR -o $PUBLIC_INET -j MASQUERADE
iptables -t nat -A POSTROUTING -s $IPCIDR2 -o $PUBLIC_INET -j MASQUERADE
EOFipt
 chmod +x /etc/openvpn/openvpn.bash
 bash /etc/openvpn/openvpn.bash
 
 # Enabling IPv4 Forwarding
 echo 1 > /proc/sys/net/ipv4/ip_forward
 
 # Starting OpenVPN server
 systemctl start openvpn@server_tcp
 systemctl enable openvpn@server_tcp
 systemctl start openvpn@server_udp
 systemctl enable openvpn@server_udp
 
 # Pulling OpenVPN no internet fixer script
 wget -qO /etc/openvpn/openvpn.bash "https://raw.githubusercontent.com/jm051484/jm051484script/master/openvpn.bash"
 chmod +x /etc/openvpn/openvpn.bash
}

function InsProxy(){
 # Removing Duplicate privoxy config
 rm -rf /etc/privoxy/config*
 
 # Creating Privoxy server config using cat eof tricks
 cat <<'myPrivoxy' > /etc/privoxy/config
# My Privoxy Server Config
user-manual /usr/share/doc/privoxy/user-manual
confdir /etc/privoxy
logdir /var/log/privoxy
filterfile default.filter
logfile logfile
listen-address 0.0.0.0:Privoxy_Port1
toggle 1
enable-remote-toggle 0
enable-remote-http-toggle 0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 1
forwarded-connect-retries 1
accept-intercepted-requests 1
allow-cgi-request-crunching 1
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
permit-access 0.0.0.0/0 IP-ADDRESS
myPrivoxy

 # Setting machine's IP Address inside of our privoxy config(security that only allows this machine to use this proxy server)
 sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/privoxy/config
 
 # Setting privoxy ports
 sed -i "s|Privoxy_Port1|$Privoxy_Port1|g" /etc/privoxy/config
 
 # Removing Duplicate Squid config
 rm -rf /etc/squid/squid.conf*
 
 # Creating Squid server config using cat eof tricks
 cat <<'mySquid' > /etc/squid/squid.conf
# My Squid Proxy Server Config
acl VPN dst IP-ADDRESS/32
http_access allow VPN
http_access deny all 
http_port Squid_Port1
http_port Squid_Port2
http_port Squid_Port3
coredump_dir /var/spool/squid
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname A.Dev
mySquid

# Setting machine's IP Address inside of our squid config(security that only allows this machine to use this proxy server)
 sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf
 
 # Setting squid ports
 sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf
 sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
 sed -i "s|Squid_Port3|$Squid_Port3|g" /etc/squid/squid.conf
 sed -i "s|MyScriptName|$MyScriptName|g" /etc/squid/squid.conf

 # Starting Proxy server
 echo -e "Restarting proxy server.."
 systemctl restart privoxy
 systemctl restart squid
}

function OvpnConfigs(){
 # Creating nginx config for our ovpn config downloads webserver
 cat <<'myNginxC' > /etc/nginx/conf.d/jm051484-ovpn-config.conf
# My OpenVPN Config Download Directory
server {
 listen 0.0.0.0:myNginx;
 server_name localhost;
 root /var/www/openvpn;
 index index.html;
}
myNginxC

 # Setting our nginx config port for .ovpn download site
 sed -i "s|myNginx|$OvpnDownload_Port|g" /etc/nginx/conf.d/jm051484-ovpn-config.conf

 # Removing Default nginx page(port 80)
 rm -rf /etc/nginx/sites-*

 # Creating our root directory for all of our .ovpn configs
 rm -rf /var/www/openvpn
 mkdir -p /var/www/openvpn

 # Now creating all of our OpenVPN Configs 
cat <<EOF15> /var/www/openvpn/GTMConfig.ovpn
client
dev tun
proto tcp
remote $IPADDR $OpenVPN_TCP_Port
remote-cert-tls server
resolv-retry infinite
connect-retry infinite
nobind
tun-mtu 1500
mssfix 1460
persist-key
persist-tun
auth-user-pass
auth none
auth-nocache
cipher none
keysize 0
comp-lzo
setenv CLIENT_CERT 0
reneg-sec 0
verb 3
#http-proxy $IPADDR $Squid_Port1
http-proxy $IPADDR $Privoxy_Port1
http-proxy-option VERSION 1.1
http-proxy-option CUSTOM-HEADER Host www.googleapis.com
http-proxy-option CUSTOM-HEADER X-Forwarded-For www.googleapis.com
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
EOF15
cat <<EOF16> /var/www/openvpn/SunConfig.ovpn
client
dev tun
proto tcp
remote $IPADDR $OpenVPN_TCP_Port
remote-cert-tls server
connect-retry infinite
resolv-retry infinite
nobind
tun-mtu 1500
mssfix 1460
persist-key
persist-tun
auth-user-pass
auth none
auth-nocache
cipher none
keysize 0
comp-lzo
setenv CLIENT_CERT 0
reneg-sec 0
verb 3
#http-proxy $IPADDR $Squid_Port1
http-proxy $IPADDR $Privoxy_Port1
http-proxy-option CUSTOM-HEADER Host www.viber.com.edgekey.net
http-proxy-option CUSTOM-HEADER X-Online-Host www.viber.com.edgekey.net
http-proxy-option CUSTOM-HEADER X-Forwarded-For www.viber.com.edgekey.net
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
EOF16
cat <<EOF162> /var/www/openvpn/SunUDPConfig.ovpn
client
dev tun
proto udp
remote $IPADDR $OpenVPN_UDP_Port
remote-cert-tls server
resolv-retry infinite
float
fast-io
nobind
tun-mtu 1500
mssfix 1460
persist-key
persist-remote-ip
persist-tun
auth-user-pass
auth none
auth-nocache
cipher none
keysize 0
comp-lzo
setenv CLIENT_CERT 0
reneg-sec 0
verb 3
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
EOF162
cat <<EOF17> /var/www/openvpn/SunNoloadConfig.ovpn
client
dev tun
proto tcp-client
remote $IPADDR $OpenVPN_TCP_Port
remote-cert-tls server
bind
float
tun-mtu 1500
tun-mtu-extra 32
mssfix 1450
mute-replay-warnings
connect-retry-max 9999
redirect-gateway def1
connect-retry 0 1
resolv-retry infinite
setenv CLIENT_CERT 0
persist-tun
persist-key
auth-user-pass
auth none
auth-nocache
auth-retry interact
cipher none
keysize 0
comp-lzo
reneg-sec 0
verb 0
nice -20
log /dev/null
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
EOF17
 # Creating OVPN download site index.html
cat <<'mySiteOvpn' > /var/www/openvpn/index.html
<!DOCTYPE html>
<html lang="en">
<!-- Simple OVPN Download site by jm051484 -->
<head><meta charset="utf-8" /><title>MyScriptName OVPN Config Download</title><meta name="description" content="MyScriptName Server" /><meta content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" name="viewport" /><meta name="theme-color" content="#000000" /><link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.8.2/css/all.css"><link href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.3.1/css/bootstrap.min.css" rel="stylesheet"><link href="https://cdnjs.cloudflare.com/ajax/libs/mdbootstrap/4.8.3/css/mdb.min.css" rel="stylesheet"></head><body><div class="container justify-content-center" style="margin-top:9em;margin-bottom:5em;"><div class="col-md"><div class="view"><img src="https://openvpn.net/wp-content/uploads/openvpn.jpg" class="card-img-top"><div class="mask rgba-white-slight"></div></div><div class="card"><div class="card-body"><h5 class="card-title">Config List</h5><br /><ul class="list-group"><li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;"><p>For Globe/TM <span class="badge light-blue darken-4">Android/iOS</span><br /><small> For EZ/GS Promo with WNP,SNS,FB and IG freebies</small></p><a class="btn btn-outline-success waves-effect btn-sm" href="http://IP-ADDRESS:NGINXPORT/GTMConfig.ovpn" style="float:right;"><i class="fa fa-download"></i> Download</a></li><li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;"><p>For Globe/TM <span class="badge light-blue darken-4">PC/Modem</span><br /><small> For EZ/GS Promo with WNP,SNS,FB and IG freebies</small></p><a class="btn btn-outline-success waves-effect btn-sm" href="http://IP-ADDRESS:NGINXPORT/GTM-PC-Config.ovpn" style="float:right;"><i class="fa fa-download"></i> Download</a></li><li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;"><p>For Sun <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /><small> For TU Promos</small></p><a class="btn btn-outline-success waves-effect btn-sm" href="http://IP-ADDRESS:NGINXPORT/SunConfig.ovpn" style="float:right;"><i class="fa fa-download"></i> Download</a></li><li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;"><p>For Sun <span class="badge light-blue darken-4">Modem</span><br /><small> Without Promo/Noload</small></p><a class="btn btn-outline-success waves-effect btn-sm" href="http://IP-ADDRESS:NGINXPORT/SunNoloadConfig.ovpn" style="float:right;"><i class="fa fa-download"></i> Download</a></li></ul></div></div></div></div></body></html>
mySiteOvpn
 
 # Setting template's correct name,IP address and nginx Port
 sed -i "s|MyScriptName|$MyScriptName|g" /var/www/openvpn/index.html
 sed -i "s|NGINXPORT|$OvpnDownload_Port|g" /var/www/openvpn/index.html
 sed -i "s|IP-ADDRESS|$IPADDR|g" /var/www/openvpn/index.html
 # Restarting nginx service
 systemctl restart nginx
 
 # Creating all .ovpn config archives
 cd /var/www/openvpn
 zip -qq -r Configs.zip *.ovpn
 cd
}
function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"
function ConfStartup(){
 # Daily reboot time of our machine
 # For cron commands, visit https://crontab.guru
 echo -e "0 4\t* * *\troot\treboot" > /etc/cron.d/b_reboot_job
 # Creating directory for startup script
 rm -rf /etc/jm051484
 mkdir -p /etc/jm051484
 chmod -R 755 /etc/jm051484
 
 # Creating startup script using cat eof tricks
 cat <<'EOFSH' > /etc/jm051484/startup.sh
#!/bin/bash
# Setting server local time
ln -fs /usr/share/zoneinfo/MyVPS_Time /etc/localtime
# Prevent DOS-like UI when installing using APT (Disabling APT interactive dialog)
export DEBIAN_FRONTEND=noninteractive
# Allowing ALL TCP ports for our machine (Simple workaround for policy-based VPS)
iptables -A INPUT -s $(wget -4qO- http://ipinfo.io/ip) -p tcp -m multiport --dport 1:65535 -j ACCEPT
# Allowing OpenVPN to Forward traffic
/bin/bash /etc/openvpn/openvpn.bash
# Deleting Expired SSH Accounts
/usr/local/sbin/delete_expired &> /dev/null
EOFSH
 chmod +x /etc/jm051484/startup.sh
 
 # Setting server local time every time this machine reboots
 sed -i "s|MyVPS_Time|$MyVPS_Time|g" /etc/jm051484/startup.sh
 # 
 rm -rf /etc/sysctl.d/99*
 # Setting our startup script to run every machine boots 
 echo "[Unit]
Description=jm051484 Startup Script
Before=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/bin/bash /etc/jm051484/startup.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/jm051484.service
 chmod +x /etc/systemd/system/jm051484.service
 systemctl daemon-reload
 systemctl start jm051484
 systemctl enable jm051484 &> /dev/null
# install ddos deflate
cd
apt-get -y install dnsutils dsniff
wget https://raw.githubusercontent.com/jm051484/Deb83in1Autoscript/master/ddos-deflate-master.zip
unzip ddos-deflate-master.zip
cd ddos-deflate-master
./install.sh
rm -rf /root/ddos-deflate-master.zip
 # Rebooting cron service
 systemctl restart cron
 systemctl enable cron
 
}
function ConfMenu(){
echo -e " Creating Menu scripts.."
cd /usr/local/sbin/
rm -rf {accounts,base-ports,base-ports-wc,base-script,bench-network,clearcache,connections,create,create_random,create_trial,delete_expired,diagnose,edit_dropbear,edit_openssh,edit_openvpn,edit_ports,edit_squid3,edit_stunnel4,locked_list,menu,options,ram,reboot_sys,reboot_sys_auto,restart_services,server,set_multilogin_autokill,set_multilogin_autokill_lib,show_ports,speedtest,user_delete,user_details,user_details_lib,user_extend,user_list,user_lock,user_unlock}
wget -q 'https://raw.githubusercontent.com/jm051484/jm051484script/master/menu.zip'
unzip -qq menu.zip
rm -f menu.zip
chmod +x ./*
dos2unix ./* &> /dev/null
sed -i 's|/etc/squid/squid.conf|/etc/privoxy/config|g' ./*
sed -i 's|http_port|listen-address|g' ./*
cd ~
echo 'clear' > /etc/profile.d/jm051484.sh
echo 'echo '' > /var/log/syslog' >> /etc/profile.d/jm051484.sh
echo 'screenfetch -p -A Android' >> /etc/profile.d/jm051484.sh
chmod +x /etc/profile.d/jm051484.sh
}
function ScriptMessage(){
 echo -e " (｡◕‿◕｡) $MyScriptName Debian VPS Installer"
 echo -e " Open release version"
 echo -e ""
 echo -e " Original Script created by Bonveio"
 echo -e " Modified by A.Dev"
 echo -e ""
}
#############################
#############################
## Installation Process
#############################
## WARNING: Do not modify or edit anything
## if you didn't know what to do.
## This part is too sensitive.
#############################
#############################
 # First thing to do is check if this machine is Debian
 source /etc/os-release
if [[ "$ID" != 'debian' ]]; then
 ScriptMessage
 echo -e "[\e[1;31mError\e[0m] This script is for Debian only, exting..." 
 exit 1
fi
 # Now check if our machine is in root user, if not, this script exits
 # If you're on sudo user, run `sudo su -` first before running this script
 if [[ $EUID -ne 0 ]];then
 ScriptMessage
 echo -e "[\e[1;31mError\e[0m] This script must be run as root, exiting..."
 exit 1
fi
 # (For OpenVPN) Checking it this machine have TUN Module, this is the tunneling interface of OpenVPN server
 if [[ ! -e /dev/net/tun ]]; then
 echo -e "[\e[1;31m×\e[0m] You cant use this script without TUN Module installed/embedded in your machine, file a support ticket to your machine admin about this matter"
 echo -e "[\e[1;31m-\e[0m] Script is now exiting..."
 exit 1
fi
 # Begin Installation by Updating and Upgrading machine and then Installing all our wanted packages/services to be install.
 ScriptMessage
 sleep 2
 InstUpdates
 
  # Configure OpenSSH and Dropbear
 echo -e "Configuring ssh..."
 InstSSH
 
 # Configure Stunnel
 echo -e "Configuring stunnel..."
 InsStunnel
 
 # Configure Webmin
 echo -e "Configuring webmin..."
 InstWebmin
 
 # Configure Privoxy and Squid
 echo -e "Configuring proxy..."
 InsProxy
 
 # Configure OpenVPN
 echo -e "Configuring OpenVPN..."
 InsOpenVPN
 
 # Configuring Nginx OVPN config download site
 OvpnConfigs
 # Some assistance and startup scripts
 ConfStartup
 ## DNS maker plugin for SUN users(for vps script usage only)
 wget -qO dnsmaker "https://raw.githubusercontent.com/jm051484/jm051484script/master/DNSMaster/debian"
 chmod +x dnsmaker
 ./dnsmaker
 rm -rf dnsmaker
 sed -i "s|http-proxy $IPADDR|http-proxy $(cat /tmp/abonv_mydns)|g" /var/www/openvpn/SunConfig.ovpn
 sed -i "s|remote $IPADDR|remote $(cat /tmp/abonv_mydns)|g" /var/www/openvpn/SunUDPConfig.ovpn
 curl -4sSL "$(cat /tmp/abonv_mydns_domain)" &> /dev/null
 mv /tmp/abonv_mydns /etc/jm051484/my_domain_name
 mv /tmp/abonv_mydns_id /etc/jm051484/my_domain_id
 rm -rf /tmp/abonv*
 # VPS Menu script v1.0
 ConfMenu
 
 # Setting server local time
 ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime
 
 clear
 cd ~
 # Running sysinfo 
 bash /etc/profile.d/jm051484.sh
 
 # Showing script's banner message
 ScriptMessage
 
 # Showing additional information from installating this script
 echo -e ""
 echo -e " Success Installation"
 echo -e ""
 echo -e " Service Ports: "
 echo -e " OpenSSH: $SSH_Port1"
 echo -e " Stunnel: $Stunnel_Port1, $Stunnel_Port2"
 echo -e " DropbearSSH: $Dropbear_Port1, $Dropbear_Port2"
 echo -e " Privoxy: $Privoxy_Port1"
 echo -e " Squid: $Squid_Port1"
 echo -e " OpenVPN TCP: $OpenVPN_TCP_Port"
 echo -e " OpenVPN UDP: $OpenVPN_UDP_Port"
 echo -e " NGiNX: $OvpnDownload_Port"
 echo -e " Webmin: 10000"
 echo -e ""
 echo -e ""
 echo -e " OpenVPN Configs Download site"
 echo -e " http://$IPADDR:$OvpnDownload_Port"
 echo -e ""
 echo -e " All OpenVPN Configs Archive"
 echo -e " http://$IPADDR:$OvpnDownload_Port/Configs.zip"
 echo -e ""
 echo -e " [For SUN Users]:"
 echo -e " Your DNS: $(cat /etc/jm051484/my_domain_name)"
 echo -e " Your DNS ID: $(cat /etc/jm051484/my_domain_id)"
 echo -e " * Keep your DNS ID in private, do not share your ID to anyone"
 echo -e ""
 echo -e ""
 echo -e " [Note] DO NOT RESELL THIS SCRIPT"
 
 # Clearing all logs from installation
 rm -rf /root/.bash_history && history -c && echo '' > /var/log/syslog
rm -f DebianVPS-Installer*
exit 1
