## Môi trường 
```sh
1 server cài Scalelite (Ubuntu 18.04, 8GB RAM, 4 CPU cores)
	+ Cài PostgreSQL
	+ Cài Redis-cache
	+ Cài NFS Server 
	+ Chạy docker scalelite-api scalelite-nginx
1 server cài Scalelite (Ubuntu 18.04, 2GB RAM, 2 CPU cores)
  + Cài đặt TURN server
3 server BBB (Ubuntu 16.04, 4GB RAM, 4 CPU cores)
	+ Chỉ cài đặt bbb_install.sh (Không cần cài Greenlight)
  + Kết nối đến TURN server 
	+ Cài NFS Client Mount share folder
```

- Scalelite bbb.azunce.xyz X.X.X.194
- TURN turn.azunce.xyz X.X.X.196
- BBB1 bbb1.azunce.xyz X.X.X.202
- BBB1 bbb2.azunce.xyz X.X.X.203

![](https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/images/scalelite.png)

## Ubuntu 18 chỉnh nameservers (TURN và Scalelite)

Chỉnh nameservers 
```sh
vi /etc/resolv.conf 
sudo apt install resolvconf -y 
echo "
# Make edits to /etc/resolvconf/resolv.conf.d/head.
nameserver 8.8.8.8
nameserver 8.8.4.4" >> /etc/resolvconf/resolv.conf.d/head

sudo service resolvconf restart
```


## Cài đặt BBB

Cài đặt 
```sh 
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6657DBE0CC86BB64
sudo apt update
wget -qO- https://ubuntu.bigbluebutton.org/bbb-install.sh | bash -s -- -v xenial-220 -a
```

Sau khi cài đặt hoàn tất tiến hành xóa gói bbb-demo 
```sh 
apt-get purge bbb-demo -y
```

Cài đặt Greenlight
https://kb.nhanhoa.com/pages/viewpage.action?pageId=33817311


Thông tin 2 node BBB sau khi cài đặt
```
URL: https://bbb1.thanhbaba.xyz/bigbluebutton/
Secret: IzzYnaA2VPhTUVfWqhCWjtaPsHTVcammuH6IlGlm9E
Email: canhdx@nhanhoa.com.vn
Password: ZGJlN2I4Zm

URL: https://bbb2.thanhbaba.xyz/bigbluebutton/
Secret: fWSIn5lLbtalWuzZX7XvIH7DUxCjCasKGsy07VNzQ
Email: canhdx@nhanhoa.com.vn
Password: ZDY4NjNlNW
```

## Share Volume Cài đặt trên node Scalelite
https://github.com/blindsidenetworks/scalelite/blob/master/sharedvolume-README.md
### Tạo các thư mục trên node Scalite
```sh 
# Create the spool directory for recording transfer from BigBlueButton
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/spool
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/spool
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/spool

# Create the temporary (working) directory for recording import
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite

# Create the directory for published recordings
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/published
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/published
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/published

# Create the directory for unpublished recordings
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chown 1000:1000 /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/unpublished
```

Cài đặt NFS server trên Scalelite
https://vitux.com/install-nfs-server-and-client-on-ubuntu/
```sh 
sudo apt install nfs-kernel-server -y 
sudo mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/spool
sudo chown nobody:nogroup /mnt/scalelite-recordings/var/bigbluebutton/spool
sudo chmod 777 /mnt/scalelite-recordings/var/bigbluebutton/spool
```

Cho phép kết nối đến thư mục 
```sh 
cat << EOF > /etc/exports
/mnt/scalelite-recordings/var/bigbluebutton/spool X.X.X.202/32(rw,sync,no_subtree_check)
/mnt/scalelite-recordings/var/bigbluebutton/spool X.X.X.203/32(rw,sync,no_subtree_check)
EOF
```

Export thư mục share 
```sh 
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

### Trên các node BBBB mount Share Folder
```
# Create a new group with GID 2000
groupadd -g 2000 scalelite-spool
# Add the bigbluebutton user to the group
usermod -a -G scalelite-spool bigbluebutton
```

Cấu hình Mount thư mục share
```sh 
sudo apt-get update -y
sudo apt-get install nfs-common -y 
sudo mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/spool
sudo mount X.X.X.194:/mnt/scalelite-recordings/var/bigbluebutton/spool /mnt/scalelite-recordings/var/bigbluebutton/spool
echo "X.X.X.194:/mnt/scalelite-recordings/var/bigbluebutton/spool /mnt/scalelite-recordings/var/bigbluebutton/spool  nfs      defaults    0       0" >> /etc/fstab
mount -a 
```

=> Nên xử lý đường Local để thực hiện việc Share, Mount NFS Folder

### Cấu hình transferrecord trên các node BBB 

Cấu hình bổ sung thêm script 
```sh 
cd /usr/local/bigbluebutton/core/scripts/post_publish
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_post_publish.rb 
chmod +x scalelite_post_publish.rb
cd /usr/local/bigbluebutton/core/scripts
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite.yml
```

Điều chỉnh `scalelite.yml` 
```sh 
sed -Ei "s|spool_dir: /var/bigbluebutton/spool|spool_dir: /mnt/scalelite-recordings/var/bigbluebutton/spool|g" /usr/local/bigbluebutton/core/scripts/scalelite.yml
```

Script `scalelite_batch_import.sh` cho phép đồng bộ các record đã có sẵn lên Server Scalelite
```sh 
cd /usr/local/bigbluebutton/core/scripts
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_batch_import.sh
```

## PostgreSQL trên node Scalelite

Cài đặt  
```
sudo apt update -y 
sudo apt install postgresql postgresql-contrib -y 
```

Đặt password cho user admin `postgres`
```sh 
sudo -u postgres psql postgres
postgres=# \password postgres
Enter new password: <Nhanhoa2020A>
Enter it again: <Nhanhoa2020A>
postgres=# \q
```

Cấu hình cho phép kết nối đến DB từ các VM docker 
```sh 
sed -Ei "s|#listen_addresses = 'localhost'|listen_addresses = '*'|g" /etc/postgresql/10/main/postgresql.conf
echo "host   all   all   172.18.0.1/16   md5" >> /etc/postgresql/10/main/pg_hba.conf
systemctl restart postgresql
```
> Dải 172.18.0.1/16 là dải Brigde của Docker, các containner `scalelite-api` và `scalelite-nginx` sẽ hoạt động trên dải này

## Cài đặt Redis Cache trên node Scalelite

Cài đặt 
```
sudo apt update -y 
sudo apt install redis-server -y 
```

Cấu hình quản lý redis, bind localhost và mật khẩu 
```sh 
sed -Ei "s|supervised no|supervised systemd|g" /etc/redis/redis.conf 	
sed -Ei "s|bind 127.0.0.1 ::1|bind 127.0.0.1 172.18.0.1 ::1|g" /etc/redis/redis.conf 
new_redis_passwd=$(openssl rand -hex 10)
echo $new_redis_passwd
sed -Ei "s|# requirepass foobared|requirepass $new_redis_passwd|g" /etc/redis/redis.conf 
```
> Bổ sung thêm cả IP của docker hosts 

Restart dịch vụ 
```sh 
sudo systemctl restart redis.service
```

Kiểm tra 
```sh 
root@bbb-scalelite:~# sudo netstat -lnp | grep redis
tcp        0      0 127.0.0.1:6379          0.0.0.0:*               LISTEN      7975/redis-server 1
tcp6       0      0 ::1:6379                :::*                    LISTEN      7975/redis-server 1
root@bbb-scalelite:~# redis-cli
127.0.0.1:6379> set a 10
(error) NOAUTH Authentication required.
127.0.0.1:6379> auth 1f3fa7b0345bc66b0f2c
OK
127.0.0.1:6379> set a 10
OK
127.0.0.1:6379> get a
"10"
127.0.0.1:6379> exit 
```

## Cài đặt Docker Containner trên node Scalelite

Cài đặt 
```sh 
sudo apt-get update -y 
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update -y 
sudo apt-get install docker-ce docker-ce-cli containerd.io -y 
```

## Cài đặt Let's cho domain Scalite

Cài đặt `certbot`
```sh 
apt-get install certbot -y
```

Cài đặt cert
```sh 
email_admin=canhdx@nhanhoa.com.vn
certbot certonly \
  --standalone \
  --agree-tos \
  --non-interactive \
  --text \
  --rsa-key-size 4096 \
  --email $email_admin \
  --domains bbb.azunce.xyz
```

Kết quả
```sh 
root@scalelite:~# certbot certonly \
  --standalone \
  --agree-tos \
  --non-interactive \
  --text \
  --rsa-key-size 4096 \
  --email $email_admin \
  --domains bbb.azunce.xyz 
Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator standalone, Installer None
Obtaining a new certificate
Performing the following challenges:
http-01 challenge for bbb.azunce.xyz
Waiting for verification...
Cleaning up challenges

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
   /etc/letsencrypt/live/bbb.azunce.xyz/fullchain.pem
   Your key file has been saved at:
   /etc/letsencrypt/live/bbb.azunce.xyz/privkey.pem
   Your cert will expire on 2020-07-25. To obtain a new or tweaked
   version of this certificate in the future, simply run certbot
   again. To non-interactively renew *all* of your certificates, run
   "certbot renew"
 - If you like Certbot, please consider supporting our work by:

   Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
   Donating to EFF:                    https://eff.org/donate-le

root@scalelite:~# ls /etc/letsencrypt/live/bbb.azunce.xyz/
README  cert.pem  chain.pem  fullchain.pem  privkey.pem
root@scalelite:~# 
```

## Cấu hình Scalelite 

Cấu hình network riêng cho Scalite 
```sh 
docker network create scalelite
```

Tạo file `/etc/default/scalelite` cấu hình mặc định cho Scalelite
```sh 
cat << EOF > /etc/default/scalelite
URL_HOST=bbb.azunce.xyz
#URL_HOST=X.X.X.194
SECRET_KEY_BASE=b063a3c8060dd7ca8f1d76d7beb58f258173c444bee7b18e41307ce6e7a64d52fcb3dcc0d7e563446c2f56ccb535ffeafaf690ab88af87fc77c96d3cdf47e947

LOADBALANCER_SECRET=9c651f640c0f06da67a2a9e6c93c7245b0df57e3fd058c3c0d8e89f2e85187a0
DATABASE_URL=postgresql://postgres:Nhanhoa2020A@172.18.0.1:5432
REDIS_URL=redis://redis:4152cff8f0f2866bf099@172.18.0.1:6379

SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton

NGINX_SSL=true
SCALELITE_NGINX_EXTRA_OPTS="--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly"
#NGINX_SSL=
#SCALELITE_NGINX_EXTRA_OPTS=

RAIL_ENV=production
EOF
```

Các tham số https://github.com/blindsidenetworks/scalelite/blob/master/README.md#required
- URL_HOST: Domain sử dụng cho API, Có thể để IP nếu có Proxy, LB phía trước, hoặc trong t/h test 
- SECRET_KEY_BASE: Random từ `openssl rand -hex 64`
- LOADBALANCER_SECRET: Random từ `openssl rand -hex 32`
- DATABASE_URL: Thông tin kết nối PostgreSQL đã tạo phía trên `postgresql://username:password@connection_url`
- REDIS_URL: Thông tin kết nối từ Redis server tạo phía trên `redis://username:password@connection_url`
- SCALELITE_TAG: Mặc đinh
- SCALELITE_RECORDING_DIR: Mặc định
- NGINX_SSL & SCALELITE_NGINX_EXTRA_OPTS: Nếu Scale chạy dưới HTTPS 

Pull images 
```sh 
source /etc/default/scalelite
docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-api
docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
```

Tạo file `/etc/systemd/system/scalelite.target` hỗ trợ stop và start toàn bộ Containner của Scalelite 
```sh 
cat << EOF> /etc/systemd/system/scalelite.target
[Unit]
Description=Scalelite
[Install]
WantedBy=multi-user.target
EOF
```

Cấu hình cho `Web Frontend` là `scalelite-api` và `scalelite-nginx`
```sh 
cat << EOF> /etc/systemd/system/scalelite-api.service
[Unit]
Description=Scalelite API
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-api
ExecStartPre=-/usr/bin/docker rm scalelite-api
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-api
ExecStart=/usr/bin/docker run --name scalelite-api --env-file /etc/default/scalelite --network scalelite --mount type=bind,source=${SCALELITE_RECORDING_DIR},target=/var/bigbluebutton blindsidenetwks/scalelite:${SCALELITE_TAG}-api
[Install]
WantedBy=scalelite.target
EOF
```

Enable 
```sh 
systemctl enable scalelite-api.service
```

```sh 
cat << EOF> /etc/systemd/system/scalelite-nginx.service
[Unit]
Description=Scalelite Nginx
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
After=scalelite-api.service
Requires=scalelite-api.service
After=remote-fs.target
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-nginx
ExecStartPre=-/usr/bin/docker rm scalelite-nginx
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
ExecStart=/usr/bin/docker run --name scalelite-nginx --env-file /etc/default/scalelite --network scalelite --publish 80:80 --publish 443:443 --mount type=bind,source=${SCALELITE_RECORDING_DIR}/published,target=/var/bigbluebutton/published,readonly $SCALELITE_NGINX_EXTRA_OPTS blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
[Install]
WantedBy=scalelite.target
EOF
```

Enable 
```sh 
systemctl enable scalelite-nginx.service
```

Khởi động dịch vụ 
```sh 
systemctl restart scalelite.target
```

Kiểm tra dịch vụ chạy 
```sh 
systemctl status scalelite-api.service scalelite-nginx.service
```

> Nếu chưa chạy kiểm tra network trong quá trình pool images hoặc bỏ đoạn pull Images 


## Khởi tạo DB cho `scalelite-api`
```sh 
docker exec -it scalelite-api bin/rake db:setup
```
http://i.imgur.com/DiOODzL.png



https://i.imgur.com/ukJwcqH.png


## Cài đặt Greenlight Fontend 
https://kb.nhanhoa.com/pages/viewpage.action?pageId=33817311


==> Chưa có p/a sử dụng Greeenlight trên Scalelite

## Quản lý các host

Thêm host
```sh 
docker exec scalelite-api bundle exec rake servers:add[https://bbb1.azunce.xyz/bigbluebutton/api,IzzYnaA2VPhTUVfWqhCWjtaPsHTVcammuH6IlGlm9E]
docker exec scalelite-api bundle exec rake servers:add[https://bbb2.azunce.xyz/bigbluebutton/api,fWSIn5lLbtalWuzZX7XvIH7DUxCjCasKGsy07VNzQ]
```

- `bbb-config --check` và bổ sung thêm `/api` sau `../bigbluebutton` => `https:domain.com/bigbluebutton/api`

List server 
```sh 
docker exec scalelite-api bundle exec rake servers
```

Remove 
```sh 
docker exec scalelite-api bundle exec rake servers:remove[id]
```

Disable host
```sh 
docker exec scalelite-api bundle exec rake servers:disable[id]
```

Enable host 
```sh 
docker exec scalelite-api bundle exec rake servers:enable[id]
```

Set host lỗi
```sh
docker exec scalelite-api bundle exec rake servers:panic[id]
```

Poll toàn bộ trạng thái 
```sh 
docker exec scalelite-api bundle exec rake poll:all
```

Xem trạng thái 
```sh
docker exec scalelite-api bundle exec rake status
```


## Cài đặt TURN server 

Cài đặt 
```sh
sudo apt-get update
sudo apt-get install coturn -y 
```

Cấu hình TLS 
```sh 
sudo apt-get install certbot -y 
```

Sinh Cert 
```sh 
sudo certbot certonly --standalone --preferred-challenges http \
    --deploy-hook "systemctl restart coturn" \
    -d turn.azunce.xyz
```

Cấu hình COTURN 
```sh 
cp /etc/turnserver.{conf,conf.bk}
secret=$(openssl rand -hex 16)
main_domain=azunce.xyz
domain=turn.azunce.xyz
sed -Ei "s|#listening-port=3478|listening-port=3478|g" /etc/turnserver.conf
sed -Ei "s|#tls-listening-port=5349|tls-listening-port=443|g" /etc/turnserver.conf
sed -Ei "s|#fingerprint|fingerprint|g" /etc/turnserver.conf
sed -Ei "s|#lt-cred-mech|lt-cred-mech|g" /etc/turnserver.conf
sed -Ei "s|#use-auth-secret|use-auth-secret|g" /etc/turnserver.conf
sed -Ei "s|#static-auth-secret=north|static-auth-secret=$secret|g" /etc/turnserver.conf
sed -Ei "s|#realm=mycompany.org|realm=$main_domain|g" /etc/turnserver.conf
sed -Ei "s|#cert=/usr/local/etc/turn_server_cert.pem|cert=/etc/letsencrypt/live/$domain/fullchain.pem|g" /etc/turnserver.conf
sed -Ei "s|#pkey=/usr/local/etc/turn_server_pkey.pem|pkey=/etc/letsencrypt/live/$domain/privkey.pem|g" /etc/turnserver.conf
sed -Ei 's|#cipher-list="DEFAULT"|cipher-list="ECDH+AESGCM:ECDH+CHACHA20:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS"|g' /etc/turnserver.conf
sed -Ei "s|#dh2066|dh2066|g" /etc/turnserver.conf
sed -Ei "s|#no-tlsv1|no-tlsv1|g" /etc/turnserver.conf
sed -Ei "s|#no-tlsv1_1|no-tlsv1_1|g" /etc/turnserver.conf
sed -Ei "s|no-tlsv1_2|#no-tlsv1_2|g" /etc/turnserver.conf
sed -Ei "s|#log-file=/var/tmp/turn.log|log-file=/var/log/coturn.log|g" /etc/turnserver.conf
```


Cấu hình Rotate log COTURN 
```sh 
cat << EOF> /etc/logrotate.d/coturn
/var/log/coturn.log
{
    rotate 30
    daily
    missingok
    notifempty
    delaycompress
    compress
    postrotate
    systemctl kill -sHUP coturn.service
    endscript
}
EOF
```

Enable Corturn 
```sh 
sed -Ei "s|#TURNSERVER_ENABLED=1|TURNSERVER_ENABLED=1|g" /etc/default/coturn
```

Restart Corturn 
```sh 
systemctl start coturn
```

## Cấu hình các server BBB sử dụng Server TURN vừa cài đặt 

```sh 
cp /usr/share/bbb-web/WEB-INF/classes/spring/turn-stun-servers.xml /opt/turn-stun-servers.xml.bk
```

Thay thế nội dung 
```sh 
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.springframework.org/schema/beans
        http://www.springframework.org/schema/beans/spring-beans-2.5.xsd">

    <bean id="stun0" class="org.bigbluebutton.web.services.turn.StunServer">
        <constructor-arg index="0" value="stun:turn.azunce.xyz"/>
    </bean>


    <bean id="turn0" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="a4cebf8e63e41222b41d4900c4d00db5"/>
        <constructor-arg index="1" value="turns:turn.azunce.xyz:443?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>
    
    <bean id="turn1" class="org.bigbluebutton.web.services.turn.TurnServer">
        <constructor-arg index="0" value="a4cebf8e63e41222b41d4900c4d00db5"/>
        <constructor-arg index="1" value="turn:turn.azunce.xyz:443?transport=tcp"/>
        <constructor-arg index="2" value="86400"/>
    </bean>

    <bean id="stunTurnService"
            class="org.bigbluebutton.web.services.turn.StunTurnService">
        <property name="stunServers">
            <set>
                <ref bean="stun0"/>
            </set>
        </property>
        <property name="turnServers">
            <set>
                <ref bean="turn0"/>
                <ref bean="turn1"/>
            </set>
        </property>
    </bean>
</beans>
```
- `a4cebf8e63e41222b41d4900c4d00db5` là giá trị trong turn.conf
- `turn.azunce.xyz` là server của turn

Restart BBB 
```sh 
bbb-conf --restart 
```

## Tích hợp vào Moodle 
- TÍch hơp Moodle 
- Tạo Course 
- Join lớp 
- Record 
- Transfer bản record 

> ## Check record trên Admin của từng node BBB ko thấy, nhưng thư mục mount share lại thấy ?

Chạy thử 
```sh 
root@bbb2:# cd /usr/local/bigbluebutton/core/scripts
root@bbb2:/usr/local/bigbluebutton/core/scripts# bash scalelite_batch_import.sh 
/usr/lib/ruby/vendor_ruby/rubygems/defaults/operating_system.rb:10: warning: constant Gem::ConfigMap is deprecated
Transferring recording for 8a927a771d80d6b3d17afff80ace046303052051-1588001298660 to Scalelite
Found recording format: presentation/8a927a771d80d6b3d17afff80ace046303052051-1588001298660
Creating recording archive
Transferring recording archive to /mnt/scalelite-recordings/var/bigbluebutton/spool
8a927a771d80d6b3d17afff80ace046303052051-1588001298660.tar

sent 1,516,020 bytes  received 35 bytes  3,032,110.00 bytes/sec
total size is 1,515,520  speedup is 1.00
root@bbb2:/usr/local/bigbluebutton/core/scripts#
```

> ## Làm thế nào để kiểm tra Bản record đã được Import rồi ?

## Tài liệu cấu hình 
https://translate.google.com/translate?hl=vi&sl=tr&tl=en&u=https%3A%2F%2Fwww.artistanbul.io%2Fblog%2F2020%2F04%2F07%2Fbigbluebutton-ve-scalelite-kurulumu%2F&sandbox=1
https://lchsk.com/how-to-connect-to-a-host-postgres-database-from-a-docker-container.html
https://github.com/blindsidenetworks/scalelite
https://docs.bigbluebutton.org/2.2/setup-turn-server.html









































=================================

> # => Chưa control được cấu hình 
Docker compose 
```sh 
cat << EOF> /etc/default/scalelite
URL_HOST=10.10.30.64
SECRET_KEY_BASE=mysecret

LOADBALANCER_SECRET=bbb_secret
DATABASE_URL=postgresql://postgres:mypassword@db:5432
REDIS_URL=redis://:1f3fa7b0345bc66b0f2c@localhost/

SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton

#NGINX_SSL=true
#SCALELITE_NGINX_EXTRA_OPTS=--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly

RAIL_ENV=production
EOF
```

Install docker-Compose
https://www.digitalocean.com/community/tutorials/how-to-install-docker-compose-on-ubuntu-18-04
```sh 
sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Tạo file Greenlight
```sh 
docker run --rm bigbluebutton/greenlight:v2 cat ./sample.env > /etc/default/greenlight
```

Create docker-file
```sh 
cat << EOF> docker-compose.yml
version: '3'

services:
  greenlight:
    entrypoint: [bin/start]
    image: bigbluebutton/greenlight:v2
    container_name: greenlight-v2
    env_file: /etc/default/greenlight
    restart: unless-stopped
    volumes:
      - /var/log/greenlight:/usr/src/app/log
    depends_on:
      - db
  db:
    image: postgres:9.5
    restart: unless-stopped
    volumes:
      - /opt/postgres:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=postgres
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=very_secret
  redis:
    image: redis:latest
    command: redis-server --appendonly yes
    restart: unless-stopped
    volumes:
      - /opt/redis:/data
  scalelite-api:
    image: blindsidenetwks/scalelite:${SCALELITE_TAG}-api
    container_name: scalelite-api
    restart: unless-stopped
    env_file: /etc/default/scalelite
    volumes:
      - ${SCALELITE_RECORDING_DIR}:/var/bigbluebutton
    depends_on:
      - db
      - redis
  scalelite-nginx:
    image: blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
    restart: unless-stopped
    container_name: scalelite-nginx
    env_file: /etc/default/scalelite
    depends_on:
      - scalelite-api
      - db
      - redis
    volumes:
      - ${SCALELITE_RECORDING_DIR}/published:/var/bigbluebutton/published
      - /etc/ssl:/etc/nginx/ssl:ro
      - /opt/greenlight/greenlight.nginx:/etc/bigbluebutton/nginx/greenlight.nginx
    ports:
      - "80:80"
      - "443:443"
  scalelite-poller:
    image: blindsidenetwks/scalelite:${SCALELITE_TAG}-poller
    container_name: scalelite-poller
    restart: unless-stopped
    env_file: /etc/default/scalelite
    depends_on:
      - scalelite-api
      - db
      - redis
  scalelite-recording-importer:
    image: blindsidenetwks/scalelite:${SCALELITE_TAG}-recording-importer
    container_name: scalelite-recording-importer
    restart: unless-stopped
    env_file: /etc/default/scalelite
    volumes:
      - ${SCALELITE_RECORDING_DIR}:/var/bigbluebutton
    depends_on:
      - scalelite-api
      - db
      - redis
EOF
```

Chạy dịch vụ 
```sh 
docker-compose up -d 
```


