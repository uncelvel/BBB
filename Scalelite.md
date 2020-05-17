1 server cài Scalelite (Ubuntu 18.04, 8GB RAM, 4 CPU cores)
  + Cài đặt TURN server
	+ Cài PostgreSQL
	+ Cài Redis-cache
	+ Cài NFS Server 
	+ Chạy docker scalelite-api scalelite-nginx
3 server BBB (Ubuntu 16.04, 4GB RAM, 4 CPU cores)
	+ Chỉ cài đặt bbb_install.sh (Không cần cài Greenlight)
  + Kết nối đến TURN server 
	+ Cài NFS Client Mount share folder





## Share Volume
https://github.com/blindsidenetworks/scalelite/blob/master/sharedvolume-README.md
Tạo các thư mục trên node Scalite
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
/mnt/scalelite-recordings/var/bigbluebutton/spool 10.10.30.0/24(rw,sync,no_subtree_check)
EOF
```

Export thư mục share 
```sh 
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

Trên các node BBBB
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
sudo mount 10.10.30.64:/mnt/scalelite-recordings/var/bigbluebutton/spool /mnt/scalelite-recordings/var/bigbluebutton/spool
echo "10.10.30.64:/mnt/scalelite-recordings/var/bigbluebutton/spool /mnt/scalelite-recordings/var/bigbluebutton/spool  nfs      defaults    0       0" >> /etc/fstab
mount -a 
```

Cấu hình transferrecord trên các node BBB 
https://github.com/blindsidenetworks/scalelite/blob/master/bigbluebutton/README.md
https://github.com/blindsidenetworks/scalelite/tree/master/bigbluebutton
```sh 
cd /usr/local/bigbluebutton/core/scripts/post_publish
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_post_publish.rb 
cd /usr/local/bigbluebutton/core/scripts
wget https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite.yml
```

Điều chỉnh `scalelite.yml` 
```sh 
sed -Ei "s|spool_dir: /var/bigbluebutton/spool|spool_dir: /mnt/scalelite-recordings/var/bigbluebutton/spool|g" /usr/local/bigbluebutton/core/scripts/scalelite.yml
```

Script `scalelite_batch_import.sh` cho phép đồng bộ các record đã có sẵn lên Server Scalelite
```sh 
cd /root/
https://raw.githubusercontent.com/blindsidenetworks/scalelite/master/bigbluebutton/scalelite_batch_import.sh
```

## PostgreSQL

https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-ubuntu-18-04
Install 
```
sudo apt update
sudo apt install postgresql postgresql-contrib
```

Đặt password cho user admin `postgres`
```sh 
sudo -u postgres psql postgres
postgres=# \password postgres
Enter new password: <Nhanhoa2020A>
Enter it again: <Nhanhoa2020A>
```


## Cài đặt Redis Cache trên node Scalelite
https://www.digitalocean.com/community/tutorials/how-to-install-and-secure-redis-on-ubuntu-18-04
```
sudo apt update -y 
sudo apt install redis-server -y 
```

Cấu hình quản lý redis, bind localhost và mật khẩu 
```sh 
sed -Ei "s|supervised no|supervised systemd|g" /etc/redis/redis.conf 	
sed -Ei "s|# bind 127.0.0.1 ::1|bind 127.0.0.1 172.17.0.1 ::1|g" /etc/redis/redis.conf 
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
127.0.0.1:6379>
```

## Cài đặt Docker Containner 
https://github.com/blindsidenetworks/scalelite/blob/master/docker-README.md
https://docs.docker.com/engine/install/ubuntu/
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

Cấu hình network riêng cho Scalite 
```sh 
docker network create scalelite
```

> Đặt password cho user admin `postgres`

> sudo -u postgres psql postgres

> postgres=# \password postgres

> Enter new password: <Nhanhoa2020A>

> Enter it again: <Nhanhoa2020A>

> psql -U postgres -h localhost 


Tạo file `/etc/default/scalelite` cấu hình mặc định cho Scalelite
```sh 
cat << EOF > /etc/default/scalelite
URL_HOST=10.10.30.64
#URL_HOST=domain.com
SECRET_KEY_BASE=b063a3c8060dd7ca8f1d76d7beb58f258173c4446ccb535ffeafaf690ab88af87fc77c96d3cdf47e947bee7b18e41307ce6e7a64d52fcb3dcc0d7e563446c2f5

LOADBALANCER_SECRET=93c7245b0df57e3fd058c3c0d8e89f2e89c651f640c0f06da67a2a9e6c5187a0
DATABASE_URL=postgresql://postgres:Nhanhoa2020A@127.0.0.1:5432/
REDIS_URL=redis://:1f3fa7b0345bc66b0f2c@localhost

SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton

#NGINX_SSL=true
#SCALELITE_NGINX_EXTRA_OPTS="--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly"
NGINX_SSL=
SCALELITE_NGINX_EXTRA_OPTS=
EOF
```

Các tham số https://github.com/blindsidenetworks/scalelite/blob/master/README.md#required
- URL_HOST: Domain sử dụng cho API, Có thể để IP nếu có Proxy, LB phía trước, hoặc trong t/h test 
- SECRET_KEY_BASE: Random từ `openssl rand -hex 64`
- LOADBALANCER_SECRET: Random từ `openssl rand -hex 32`
- DATABASE_URL: Thông tin kết nối PostgreSQL đã tạo phía trên `postgresql://username:password@connection_url`
- REDIS_URL: Thông tin kết nối từ Redis server tạo phía trên `redis://username:password@connection_url`
1f3fa7b0345bc66b0f2c
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


## Khởi tạo DB cho `scalelite-api`
```sh 
docker exec -it scalelite-api bin/rake db:setup
```
> # ==> Lỗi https://paste.cloud365.vn/?ad4ff5b74b00ba8c#P/movqtlfpKLVYGcltbEhv1op78H3KdIw/4AEf4f628=

.


Cho phép dải IP docker kết nối 
https://lchsk.com/how-to-connect-to-a-host-postgres-database-from-a-docker-container.html
Xem IP của docker image 
docker inspect <container id>
ping thử 
https://i.imgur.com/gIGNQha.png


```sh
URL_HOST=10.10.30.64
#URL_HOST=domain.cm
SECRET_KEY_BASE=b063a3c8060dd7ca8f1d76d7beb58f258173c4446ccb535ffeafaf690ab88af87fc77c96d3cdf47e947bee7b18e41307ce6e7a64d52fcb3dcc0d7e563446c2f5
LOADBALANCER_SECRET=93c7245b0df57e3fd058c3c0d8e89f2e89c651f640c0f06da67a2a9e6c5187a0
DATABASE_URL=postgresql://postgres:Nhanhoa2020A@172.17.0.1:5432
REDIS_URL=redis://redis:1f3fa7b0345bc66b0f2c@172.17.0.1:6379
SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton
#NGINX_SSL=true
#SCALELITE_NGINX_EXTRA_OPTS="--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly"
NGINX_SSL=
SCALELITE_NGINX_EXTRA_OPTS=

RAIL_ENV=production
```

## Cài đặt Greenlight Fontend 
https://kb.nhanhoa.com/pages/viewpage.action?pageId=33817311


==> Chưa có p/a sử dụng Greeenlight trên Scalelite

## Quản lý các host

./bin/rake servers

./bin/rake servers:add[url,secret]
> bbb-conf --secret +/api

https://i.imgur.com/t12pMqk.png

./bin/rake servers:remove[id]

./bin/rake servers:disable[id]

./bin/rake servers:enable[id]

https://i.imgur.com/OItwi2x.png

./bin/rake servers:panic[id]

./bin/rake poll:all

https://i.imgur.com/QRtjgc9.png

./bin/rake status



./bin/rake servers:add[http://10.10.30.61/bigbluebutton/api,wiCRjqdJZ3CTLRB6oUsMl3jgZ5ziT2V6yq1nmQ22hU]
./bin/rake servers:add[http://10.10.30.62/bigbluebutton/api,Q7faWDzSbJ80KEWn2caWieUISSs9j3OKWt85t9oSI0]
./bin/rake servers:add[http://10.10.30.63/bigbluebutton/api,zvmwieYYo1j0jF60l9f5sgqcakOrsX60ElwNFoPz94]

    URL: http://10.10.30.61/bigbluebutton/
    Secret: wiCRjqdJZ3CTLRB6oUsMl3jgZ5ziT2V6yq1nmQ22hU

    Link to the API-Mate:
    https://mconf.github.io/api-mate/#server=http://10.10.30.61/bigbluebutton/&sharedSecret=wiCRjqdJZ3CTLRB6oUsMl3jgZ5ziT2V6yq1nmQ22hU

    URL: http://10.10.30.62/bigbluebutton/
    Secret: Q7faWDzSbJ80KEWn2caWieUISSs9j3OKWt85t9oSI0

    Link to the API-Mate:
    https://mconf.github.io/api-mate/#server=http://10.10.30.62/bigbluebutton/&sharedSecret=Q7faWDzSbJ80KEWn2caWieUISSs9j3OKWt85t9oSI0


    URL: http://10.10.30.63/bigbluebutton/
    Secret: zvmwieYYo1j0jF60l9f5sgqcakOrsX60ElwNFoPz94

    Link to the API-Mate:
    https://mconf.github.io/api-mate/#server=http://10.10.30.63/bigbluebutton/&sharedSecret=zvmwieYYo1j0jF60l9f5sgqcakOrsX60ElwNFoPz94

33024dd3-1514-4824-95b5-24496f27834e








## Tài liệu cấu hình 
https://translate.google.com/translate?hl=vi&sl=tr&tl=en&u=https%3A%2F%2Fwww.artistanbul.io%2Fblog%2F2020%2F04%2F07%2Fbigbluebutton-ve-scalelite-kurulumu%2F&sandbox=1
https://lchsk.com/how-to-connect-to-a-host-postgres-database-from-a-docker-container.html
https://github.com/blindsidenetworks/scalelite


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


