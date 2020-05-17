#!/bin/bash
# BBB create Let's Encrypt 
# Integration with script bbb*.sh
# CanhDX NhanHoa Cloud Team 
# 2020-04-25
# Version 2 

# Variables
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

apt-get install certbot -y 

if [ "$#" -lt 1 ]; then
    echo "[${green}INFORMATION${reset}] Script can truyen vao domain"
    echo '---------------------------'
    echo "VD: bash $0 domain.example.com"
    exit 0
fi

domain=$(echo $1 | tr "[:upper:]" "[:lower:]")
ip=$(curl ifconfig.me)
domain_ip=$(echo $(host $domain |awk '{print $NF}'))

if [[ $ip != $domain_ip ]]; then 
    echo "[${red}WARNING${reset}] Domain chua duoc tro ve IP hoac ko chinh xac"
    exit 0  
fi 

# Change domain hostname 
echo "[${green}INFORMATION${reset}] Doi domain name cua BBB"
sudo bbb-conf --setip $domain

# Require SSL cert 
if [[ -d /etc/letsencrypt/live/$domain ]]; then 
  echo "[${red}WARNING${reset}] Cert da ton tai"
  echo '---------------------------'
else 

  echo "[${green}INFORMATION${reset}] Tien hanh cai dat Cert"
  echo '---------------------------'
  read -p "[${green}REQUIRE${reset}] Nhap email quan tri: " email_admin

  # -> Check email 
  if [[ "$email_admin" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]
  then
      echo "Email dung format"
  else
      echo "[${red}WARNING${reset}] Email khong dung format su dung admin@localhost.local"
      email_admin="admin@localhost.local"
  fi

  certbot certonly \
    --webroot \
    --agree-tos \
    --non-interactive \
    --text \
    --rsa-key-size 4096 \
    --email $email_admin \
    --webroot-path /var/www/bigbluebutton-default \
    --domains $domain
fi 

# Check to continue
if [[ ! -d /etc/letsencrypt/live/$domain ]]; then 
  echo 
  echo "[${red}WARNING${reset}] Cai dat Cert khong thanh cong, revert lai setting cu"
  echo '---------------------------'
  sudo bbb-conf --setip $domain_ip
  exit 0
fi 

# Insert crontab for renew cert
echo 
echo "[${green}INFORMATION${reset}] Cau hinh tu dong renew Cert Let's Encrypt"
echo '---------------------------'
echo "30 2 * * 1 /usr/bin/certbot renew >> /var/log/le-renew.log
35 2 * * 1 /bin/systemctl reload nginx" > /etc/crontab

systemctl restart cron

# Insert config https to nginx
echo 
echo "[${green}INFORMATION${reset}] Cau hinh Nginx su dung SSL"
echo '---------------------------'
mv /etc/nginx/sites-available/bigbluebutton /opt/nginx-bigbluebutton.bk
wget -O /etc/nginx/sites-available/bigbluebutton https://scripts.cloud365.vn/bbb-nginx.conf
chmod 644 /etc/nginx/sites-available/bigbluebutton
sed -Ei "s|bigbluebutton.example.com|$domain|g" /etc/nginx/sites-available/bigbluebutton

mv /etc/nginx/sites-available/default /opt/nginx-default.bk
wget -O /etc/nginx/sites-available/default https://scripts.cloud365.vn/bbb-nginx-default.conf
chmod 644 /etc/nginx/sites-available/default
sed -Ei "s|bigbluebutton.example.com|$domain|g" /etc/nginx/sites-available/default

# Configure FreeSWITCH for using SSL
echo 
echo "[${green}INFORMATION${reset}] Cau hinh FreeSWITCH su dung SSL"
echo '---------------------------'
sed -Ei "s|http://$ip:5066;|https://$ip:7443;|g" /etc/bigbluebutton/nginx/sip.nginx

# Configure BigBlueButton to load session via HTTPS
echo 
echo "[${green}INFORMATION${reset}] Cau hinh BBB load session thong qua HTTPS"
echo '---------------------------'
sed -Ei "s|bigbluebutton.web.serverURL=http://|bigbluebutton.web.serverURL=https://|g" /usr/share/bbb-web/WEB-INF/classes/bigbluebutton.properties

sed -Ei "s|jnlpUrl=http://|jnlpUrl=https://|g" /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties
sed -Ei "s|jnlpFile=http://|jnlpFile=https://|g" /usr/share/red5/webapps/screenshare/WEB-INF/screenshare.properties

sed -Ei 's|http://|https://|g' /var/www/bigbluebutton/client/conf/config.xml

sed -Ei "s|ws://|wss://|g" /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml
sed -Ei "s|url: http://|url: https://|g" /usr/share/meteor/bundle/programs/server/assets/app/config/settings.yml

old_playback_protocol=$(cat /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml | grep playback_protocol | awk '{print $2}')
sed -Ei "s|playback_protocol: $old_playback_protocol|playback_protocol: https|g" /usr/local/bigbluebutton/core/scripts/bigbluebutton.yml

sudo bbb-conf --restart

# Edit .env Greenlight 
echo 
echo "[${green}INFORMATION${reset}] Cau hinh Greenlight su dung domain"
echo '---------------------------'
sed -Ei "s|http://$ip|https://$domain|g" /root/greenlight/.env
# Change approval register
sed -Ei "s|DEFAULT_REGISTRATION=open|DEFAULT_REGISTRATION=approval|g" /root/greenlight/.env

cd /root/greenlight/
docker-compose down
rm -rf /root/greenlight/db
> /root/greenlight/log/production.log
docker-compose up -d

# Create Admin user
echo 
echo "[${green}INFORMATION${reset}] Cho 30s Greenlight start...."
echo '---------------------------'
sleep 30s
echo 
echo "[${green}INFORMATION${reset}] Cau hinh tai khoan admin"
echo '---------------------------'
cd /root/greenlight/
password=$(date +%s | sha256sum | base64 | head -c 10 ; echo)
echo "Domain: https://$domain"
docker exec greenlight-v2 bundle exec rake user:create["Admin","$email_admin","$password","admin"]

# Remove Script 
echo 
echo "[${green}INFORMATION${reset}] Remove scripts"
echo '---------------------------'
rm -f $0

echo "[${green}INFORMATION${reset}] Hoan tat"
echo '---------------------------'
