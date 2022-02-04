#!/bin/bash
# Script mod updated By Prince
# Commad Install auto setup was changed 
# due to an error while performing the installation
# Dec 31 2021 updated
# ==============================
#    ! HAPPY NEW YEAR GUYSS !
# ==============================

# update
apt-get update; apt-get -y upgrade;

# install webserver extensions
apt-get -y install nginx
apt-get -y install php7.4-fpm php7.4-cli libssh2-1 php-ssh2 php7.4


# install essential package
apt-get -y install nano iptables-persistent dnsutils screen whois ngrep unzip unrar tar unzip zip certbot
apt-get -y install build-essential
apt-get -y install libio-pty-perl libauthen-pam-perl apt-show-versions libnet-ssleay-perl
apt-get -y install bmon iftop htop nmap axel nano iptables traceroute sysv-rc-conf dnsutils bc nethogs openvpn vnstat less screen psmisc apt-file whois ptunnel ngrep mtr git zsh mrtg snmp snmpd snmp-mibs-downloader unzip unrar rsyslog debsums rkhunter
apt-get -y install libio-pty-perl libauthen-pam-perl apt-show-versions


# Install Webserver
if [ $(cat /etc/debian_version) == '10.9' ]; then
  VERSION=10.9
  apt -y --purge remove apache2*;
  apt -y install nginx
  apt -y install php-fpm php-cli libssh2-1 php-ssh2 php
  sed -i 's/listen = \/run\/php\/php7.4-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php/7.4/fpm/pool.d/www.conf
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default
  wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/nginx.conf"
  wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/vps.conf"
  wget -O /etc/nginx/conf.d/monitoring.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/monitoring.conf"
  mkdir -p /home/vps/public_html
  wget -O /home/vps/public_html/index.php "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Panel/index.php"
  service php7.4-fpm restart
  service nginx restart
elif [ $(cat /etc/debian_version) == '9.13' ]; then
  VERSION=9.13
  apt -y --purge remove apache2*;
  apt -y install nginx
  apt -y install php7.0-fpm php7.0-cli libssh2-1 php-ssh2 php7.0
  sed -i 's/listen = \/run\/php\/php7.0-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php/7.0/fpm/pool.d/www.conf
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default
  wget -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/nginx.conf"
  wget -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/vps.conf"
  wget -O /etc/nginx/conf.d/monitoring.conf "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Other/monitoring.conf"
  mkdir -p /home/vps/public_html
  wget -O /home/vps/public_html/index.php "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Panel/index.php"
  service php7.0-fpm restart
  service nginx restart
fi

# OpenVPN Monitoring
apt-get install -y gcc libgeoip-dev python-virtualenv python-dev geoip-database-extra uwsgi uwsgi-plugin-python
wget -O /srv/openvpn-monitor.tar "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Panel/openvpn-monitor.tar"
cd /srv
tar xf openvpn-monitor.tar
cd openvpn-monitor
virtualenv .
. bin/activate
pip install -r requirements.txt
wget -O /etc/uwsgi/apps-available/openvpn-monitor.ini "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Panel/openvpn-monitor.ini"
ln -s /etc/uwsgi/apps-available/openvpn-monitor.ini /etc/uwsgi/apps-enabled/

# GeoIP For OpenVPN Monitor
mkdir -p /var/lib/GeoIP
wget -O /var/lib/GeoIP/GeoLite2-City.mmdb.gz "https://raw.githubusercontent.com/JanganCrut/Deb9-10/main/Resources/Panel/GeoLite2-City.mmdb.gz"
gzip -d /var/lib/GeoIP/GeoLite2-City.mmdb.gz


# install vnstat gui
cd /home/vps/public_html/
wget https://raw.githubusercontent.com/daybreakersx/premscript/master/vnstat_php_frontend-1.5.1.tar.gz
tar xf vnstat_php_frontend-1.5.1.tar.gz
rm vnstat_php_frontend-1.5.1.tar.gz
mv vnstat_php_frontend-1.5.1 vnstat
cd vnstat
sed -i "s/\$iface_list = array('eth0', 'sixxs');/\$iface_list = array('eth0');/g" config.php
sed -i "s/\$language = 'nl';/\$language = 'en';/g" config.php
sed -i 's/Internal/Internet/g' config.php
sed -i '/SixXS IPv6/d' config.php
cd

# install mrtg
wget -O /etc/snmp/snmpd.conf "https://raw.githubusercontent.com/daybreakersx/premscript/master/snmpd.conf"
wget -O /root/mrtg-mem.sh "https://raw.githubusercontent.com/daybreakersx/premscript/master/mrtg-mem.sh"
chmod +x /root/mrtg-mem.sh
cd /etc/snmp/
sed -i 's/TRAPDRUN=no/TRAPDRUN=yes/g' /etc/default/snmpd
service snmpd restart
snmpwalk -v 1 -c public localhost 1.3.6.1.4.1.2021.10.1.3.1
mkdir -p /home/vps/public_html/mrtg
cfgmaker --zero-speed 100000000 --global 'WorkDir: /home/vps/public_html/mrtg' --output /etc/mrtg.cfg public@localhost
curl "https://raw.githubusercontent.com/daybreakersx/premscript/master/mrtg.conf" >> /etc/mrtg.cfg
sed -i 's/WorkDir: \/var\/www\/mrtg/# WorkDir: \/var\/www\/mrtg/g' /etc/mrtg.cfg
sed -i 's/# Options\[_\]: growright, bits/Options\[_\]: growright/g' /etc/mrtg.cfg
indexmaker --output=/home/vps/public_html/mrtg/index.html /etc/mrtg.cfg
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
if [ -x /usr/bin/mrtg ] && [ -r /etc/mrtg.cfg ]; then mkdir -p /var/log/mrtg ; env LANG=C /usr/bin/mrtg /etc/mrtg.cfg 2>&1 | tee -a /var/log/mrtg/mrtg.log ; fi
cd

# xml parser
cd
apt-get install -y libxml-parser-perl


# finishing
cd
chown -R www-data:www-data /home/vps/public_html
/etc/init.d/nginx restart
/etc/init.d/openvpn restart
/etc/init.d/cron restart
/etc/init.d/ssh restart
/etc/init.d/dropbear restart
/etc/init.d/fail2ban restart
/etc/init.d/stunnel4 restart
service php7.4-fpm restart
service uwsgi restart
systemctl daemon-reload
service squid restart
service pptpd restart
/etc/init.d/webmin restart

# clearing history
rm -rf ~/.bash_history && history -c
echo "unset HISTFILE" >> /etc/profile

# remove unnecessary files
apt -y autoremove
apt -y autoclean
apt -y clean
