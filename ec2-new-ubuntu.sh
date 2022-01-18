#!/bin/bash
# 以 sudo 權限執行
# sudo sh ./ec2-new-buuntu.sh
# 此腳本會安裝 nginx + php + mariadb 在 ubuntu 上
# 並設定資料庫使用者 + nginx 網站設定檔

# 專案設定
# 專案名稱 (僅限英數，會以此建立資料夾)
PROJECT=codepulse
# 專案網址 (僅限英數，會以此建立 nginx 網站設定檔)
SITE=codepulse.com
# php 版本
PHP_VERSION=8.0
# Comopser 版本 (留空則安裝最新版)
COMPOSER_VERSION=

# 資料庫相關
# 是否在本機安裝 PostgreSQL，使用 RDS 請設定為 false
INSTALL_PGSQL=true
# 管理員密碼
PGSQL_ROOT_PASS=H9r.pWeGpvy=3Ph8
# 資料庫名稱
PGSQL_DATABASE=cp_codepulse
# 資料庫使用者帳號
PGSQL_NAME=codepulse
# 資料庫使用者密碼
PGSQL_PASS=AemFv26V-+B%#x.Y

# 是否在本機安裝 MariaDB，使用 RDS 請設定為 false
INSTALL_MARIADB=true
# 管理員密碼
MARIA_ROOT_PASS=H9r.pWeGpvy=3Ph8
# 資料庫名稱
MARIA_DATABASE=cp_codepulse
# 資料庫使用者帳號
MARIA_NAME=codepulse
# 資料庫使用者密碼
MARIA_PASS=AemFv26V-+B%#x.Y

# 是否在本機安裝 Redis，使用 RDS 請設定為 false
INSTALL_REDIS=true
# Redis 密碼，空則表示不用密碼
# 如果有設定密碼記得更改 phpRedisAdmin/includes/config.inc.php 內的設定值
# 將 $config['servers']['auth'] 的註解取消並寫上相同密碼
REDIS_PASS=

# SSR 相關
# 是否安裝並設定 SSR
INSTALL_SSR=true
# rendora 設定檔名稱
RENDORA_CONFIG=${SITE}.config.yml
# rendora 監聽 port
RENDORA_LISTEN_PORT=3001
# ssr 導向 prot
SSR_PROT=8081
# chrmoe 監聽 port，為了多站共通使用請勿改
CHROME_PORT=9222

# SSL 相關
# 是否在本機安裝免費的 SSL 憑證
installFreeSLL=false

# 此腳本路徑
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# 更新系統
apt update -y
apt upgrade -y
# 設定時區
timedatectl set-timezone Asia/Taipei
echo "Asia/Taipei" | sudo tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata
# 安裝 php 庫
apt install -y software-properties-common
add-apt-repository -y ppa:ondrej/php
# 安裝 PostgreSQL 庫
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# 安裝 mariadb 庫
apt-get install software-properties-common
apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
add-apt-repository -y 'deb [arch=amd64,arm64,ppc64el] https://ftp.ubuntu-tw.org/mirror/mariadb/repo/10.5/ubuntu focal main'
# 安裝所需套件
apt update -y
apt upgrade -y
apt install -y tcl tk expect curl git unzip nginx
if [ $PHP_VERSION < 8 ]; then
    apt install -y \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-bz2 \
        php${PHP_VERSION}-cgi \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gmagick \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-json \
        php${PHP_VERSION}-ldap \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip
else
    apt install -y \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-bz2 \
        php${PHP_VERSION}-cgi \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gmagick \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-ldap \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip
fi

# 安裝 composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '906a84df04cea2aa72f40b5f787e49f22d4c2f19492ac310e8cba5b96ac8b64115ac402c8cd292b8a03482574915d1a8') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
if [ ${COMPOSER_VERSION} ]; then
    php composer-setup.php --version=${COMPOSER_VERSION}
else
    php composer-setup.php
fi
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/local/bin/composer

# 安裝 PostgreSQL
if $INSTALL_PGSQL; then
    apt install -y postgresql postgresql-client postgresql-client-common postgresql-common postgresql-contrib
su postgres << EOF
PGPASSWORD=${PGSQL_ROOT_PASS} psql -c "ALTER USER postgres WITH PASSWORD '${PGSQL_ROOT_PASS}';"
PGPASSWORD=${PGSQL_ROOT_PASS} psql -c "CREATE USER ${PGSQL_NAME} WITH PASSWORD '${PGSQL_PASS}';"
PGPASSWORD=${PGSQL_ROOT_PASS} psql -c "CREATE DATABASE ${PGSQL_DATABASE} OWNER '${PGSQL_NAME}';"
PGPASSWORD=${PGSQL_ROOT_PASS} psql -c "GRANT ALL PRIVILEGES ON DATABASE ${PGSQL_DATABASE} TO ${PGSQL_NAME};"
EOF
    PG_CONF=$(find /etc/postgresql/ -type f -name "postgresql.conf")
    PG_HBA=$(find /etc/postgresql/ -type f -name "pg_hba.conf")
    sed -i "s/#listen_addresses.*/listen_addresses = '*'/" ${PG_CONF}
    sed -i 's/local.*all.*postgres.*peer/local   all             postgres                                md5/' ${PG_HBA}
    sed -i 's/local.*all.*all.*peer/local   all             all                                     md5/' ${PG_HBA}
    systemctl restart postgresql
fi

# 安裝 MariaDB
if $INSTALL_MARIADB; then
    apt install -y mariadb-server
SECURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Switch to unix_socket authentication\"
send \"N\r\"
expect \"Change the root password?\"
send \"Y\r\"
expect \"New password:\"
send \"${MARIA_ROOT_PASS}\r\"
expect \"Re-enter new password:\"
send \"${MARIA_ROOT_PASS}\r\"
expect \"Remove anonymous users?\"
send \"Y\r\"
expect \"Disallow root login remotely?\"
send \"Y\r\"
expect \"Remove test database and access to it?\"
send \"Y\r\"
expect \"Reload privilege tables now?\"
send \"Y\r\"
expect eof
")
    echo $SECURE_MYSQL
    mysql -uroot -p${MARIA_ROOT_PASS} -e "SET GLOBAL time_zone = '+8:00';"
    mysql -uroot -p${MARIA_ROOT_PASS} -e "FLUSH PRIVILEGES;"
    mysql -uroot -p${MARIA_ROOT_PASS} -e "CREATE DATABASE ${MARIA_DATABASE};"
    mysql -uroot -p${MARIA_ROOT_PASS} -e "CREATE USER '${MARIA_NAME}'@'localhost' IDENTIFIED BY '${MARIA_PASS}';"
    mysql -uroot -p${MARIA_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${MARIA_DATABASE}.* TO '${MARIA_NAME}'@'localhost';"
fi

# 安裝 Redis
if $INSTALL_REDIS; then
    apt install -y redis-server
    if [ "${REDIS_PASS}" != "" ]; then
        sed -i 's/# requirepass.*/requirepass '${REDIS_PASS}'/' /etc/redis/redis.conf
        systemctl restart redis.service
    fi
fi

# 建立網站資料夾
usermod -a -G www-data ubuntu
mkdir -p /home/www-data/${PROJECT}
chown www-data:www-data -Rf /home/www-data
chmod -R 0774 /home/www-data

# 修改 nginx 設定檔
sed -i 's|roow.*|roow "/home/www-data/'${PROJECT}'"|1' /etc/nginx/sites-available/default
# 設定可上傳檔案大小
sed -i '/client_max_body_size/d' /etc/nginx/nginx.conf
sed -i '/http {/a\        client_max_body_size 50M;' /etc/nginx/nginx.conf
systemctl reload nginx

# 修改 php 設定檔
# 上傳檔案大小上限（單一檔案大小）
sed -i 's/upload_max_filesize.*/upload_max_filesize = 50M/' /etc/php/${PHP_VERSION}/fpm/php.ini
# POST 大小上限（所有檔案大小加總）
sed -i 's/post_max_size.*/post_max_size = 200M/' /etc/php/${PHP_VERSION}/fpm/php.ini
# 記憶體用量上限
sed -i 's/memory_limit.*/memory_limit = 512M/' /etc/php/${PHP_VERSION}/fpm/php.ini
# PHP 指令稿執行時間上限（秒）
sed -i 's/max_execution_time.*/max_execution_time = 600/' /etc/php/${PHP_VERSION}/fpm/php.ini
# PHP 指令稿解析輸入資料時間上限（秒）
sed -i 's/^max_input_time.*/max_input_time = 600/' /etc/php/${PHP_VERSION}/fpm/php.ini
# 使用短語法
sed -i 's/^short_open_tag.*/short_open_tag = on/' /etc/php/${PHP_VERSION}/fpm/php.ini
# 時區
sed -i 's|;date\.timezone.*|date.timezone = Asia/Taipei|' /etc/php/${PHP_VERSION}/fpm/php.ini
systemctl restart php${PHP_VERSION}-fpm

# 建立網站設定檔
# 預設站點
rm -f /etc/nginx/sites-available/default
bash -c 'cat <<\EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    #root "/var/www";
    root "/home/www-data/'${PROJECT}'";
    server_name _;

    rewrite "^/(\w{2}\-\w{2})?\/?sitemap.xml$" /index.php?route=feed/google_sitemap&_language_=$1 last;
    rewrite ^/googlebase.xml$ /index.php?route=feed/google_base last;
    rewrite ^/system/download/(.*) /index.php?route=error/not_found last;

    if (!-f $request_filename){
        set $rule_3 1$rule_3;
    }
  
    if (!-d $request_filename){
        set $rule_3 2$rule_3;
    }

    if ($uri !~ ".*\.(ico|gif|jpg|jpeg|png|js|css)"){
        set $rule_3 3$rule_3;
    }

    if ($rule_3 = "321"){
        rewrite "^/(\w{2}\-\w{2})?\/?([^?]*)" /index.php?_route_=$2&_language_=$1 last;
    }
EOF'
if $INSTALL_SSR; then
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/default
    location / {
        proxy_pass http://localhost:'${RENDORA_LISTEN_PORT}';
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        try_files $uri $uri/ /index.php?$args;
    }
EOF'
else
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/default
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php'${PHP_VERSION}'-fpm.sock;
    }
EOF'
fi
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/default
}
EOF'

# 站點設定檔
bash -c 'cat <<\EOF > /etc/nginx/sites-available/'${PROJECT}'.conf
# 如果要 80 port 都導向 443，把這裡註解拿掉
#server {
#    listen 80;
#    server_name '${SITE}' *.'${SITE}';
#    return 308 https://$host$request_uri;
#}

server {
    # 預設關閉 443，如果需要 SSL 驗證請安裝好證書後修改設定
    listen 80;
    #listen 443 ssl http2;
    server_name '${SITE}' *.'${SITE}';
    root "/home/www-data/'${PROJECT}'";

    index index.html index.htm index.php;
    rewrite "^/(\w{2}\-\w{2})?\/?sitemap.xml$" /index.php?route=feed/google_sitemap&_language_=$1 last;
    rewrite ^/googlebase.xml$ /index.php?route=feed/google_base last;
    rewrite ^/system/download/(.*) /index.php?route=error/not_found last;

    if (!-f $request_filename){
        set $rule_3 1$rule_3;
    }
  
    if (!-d $request_filename){
        set $rule_3 2$rule_3;
    }

    if ($uri !~ ".*\.(ico|gif|jpg|jpeg|png|js|css)"){
        set $rule_3 3$rule_3;
    }

    if ($rule_3 = "321"){
        rewrite "^/(\w{2}\-\w{2})?\/?([^?]*)" /index.php?_route_=$2&_language_=$1 last;
    }
EOF'
if $INSTALL_SSR; then
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/'${PROJECT}'.conf
    location / {
        proxy_pass http://localhost:'${RENDORA_LISTEN_PORT}';
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto;
        try_files $uri $uri/ /index.php?$args;
    }
EOF'
else
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/'${PROJECT}'.conf
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php'${PHP_VERSION}'-fpm.sock;
    }
EOF'
fi
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/'${PROJECT}'.conf
    # Enable SSL
    #ssl_certificate "ssl.crt";
    #ssl_certificate_key "ssl.key";
    #ssl_session_timeout 5m;
    #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    #ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP;
    #ssl_prefer_server_ciphers on;
    
    charset utf-8;
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt { access_log off; log_not_found off; }
    location ~ /\.ht {
        deny all;
    }
}
EOF'

if $INSTALL_SSR; then
bash -c 'cat <<\EOF >> /etc/nginx/sites-available/'${PROJECT}'.conf

server {
    listen '${SSR_PROT}';
    server_name localhost;
    root "/home/www-data/'${PROJECT}'";

    index index.html index.htm index.php;
    rewrite "^/(\w{2}\-\w{2})?\/?sitemap.xml$" /index.php?route=feed/google_sitemap&_language_=$1 last;
    rewrite ^/googlebase.xml$ /index.php?route=feed/google_base last;
    rewrite ^/system/download/(.*) /index.php?route=error/not_found last;

    if (!-f $request_filename){
        set $rule_3 1$rule_3;
    }

    if (!-d $request_filename){
        set $rule_3 2$rule_3;
    }

    if ($uri !~ ".*\.(ico|gif|jpg|jpeg|png|js|css)"){
        set $rule_3 3$rule_3;
    }

    if ($rule_3 = "321"){
        rewrite "^/(\w{2}\-\w{2})?\/?([^?]*)" /index.php?_route_=$2&_language_=$1 last;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php'${PHP_VERSION}'-fpm.sock;
    }

    # Enable SSL
    #ssl_certificate "ssl.crt";
    #ssl_certificate_key "ssl.key";
    #ssl_session_timeout 5m;
    #ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    #ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP;
    #ssl_prefer_server_ciphers on;

    charset utf-8;
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt { access_log off; log_not_found off; }
    location ~ /\.ht {
        deny all;
    }
}
EOF'
fi
ln -s /etc/nginx/sites-available/${PROJECT}.conf /etc/nginx/sites-enabled/${PROJECT}.conf
chmod 777 /etc/nginx/sites-enabled/${PROJECT}.conf
chmod 644 /etc/nginx/sites-available/${PROJECT}.conf
chmod 644 /etc/nginx/sites-available/default
systemctl reload nginx

# 安裝 SSR
if $INSTALL_SSR; then
    # 安裝 chrome
    cd $SCRIPT_DIR
    apt install -y make libappindicator1 fonts-liberation gdebi-core
    apt install -f
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    gdebi --non-interactive google-chrome*.deb
    # 下載 go
    wget https://go.dev/dl/go1.17.6.linux-amd64.tar.gz && \
    tar zxvf go1.17.6.linux-amd64.tar.gz
    PATH=$PATH:$SCRIPT_DIR/go/bin
    # 下載 rendora
    git clone https://github.com/rendora/rendora
    # 編譯 rendora
    cd ./rendora && make build && make install
    cd $SCRIPT_DIR
    # 移除下載項
    rm -rf google-chrome*.deb go*.tar.gz ./go ./rendora

    # 寫 rendora 設定檔
bash -c 'cat <<\EOF > '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
debug: false
listen:
    address: 0.0.0.0
    port: '${RENDORA_LISTEN_PORT}'
EOF'
if $INSTALL_REDIS; then
    if [ "${REDIS_PASS}" != "" ]; then
bash -c 'cat <<\EOF >> '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
cache:
    type: redis
    timeout: 6000
    redis:
        address: localhost:6379
        password: '${REDIS_PASS}'
        db: 0
EOF'
    else
bash -c 'cat <<\EOF >> '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
cache:
    type: redis
    timeout: 6000
    redis:
        address: localhost:6379
        db: 0
EOF'
    fi
else
bash -c 'cat <<\EOF >> '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
cache:
    type: local
    timeout: 6000
EOF'
fi
bash -c 'cat <<\EOF >> '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
target:
    url: "http://localhost:'${SSR_PROT}'"
backend:
    url: "http://localhost:'${SSR_PROT}'"
headless:
    waitAfterDOMLoad: 5000
    timeout: 15
    internal:
        url: http://localhost:'${CHROME_PORT}'
    blockedURLs:
        - "*.png"
        - "*.jpg"
        - "*.jpeg"
        - "*.webp"
        - "*.gif"
        - "*.css"
        - "*.woff2"
        - "*.svg"
        - "*.woff"
        - "*.ttf"
        - "*.font"
        - "https://www.youtube.com/*"
        - "https://www.google-analytics.com/*"
        - "https://fonts.googleapis.com/*"
output:
    minify: true
filters:
    userAgent:
        defaultPolicy: blacklist
        exceptions:
            keywords:
                - bot
                - slurp
                - bing
                - yandex
                - crawler
    paths:
        defaultPolicy: whitelist
        exceptions:
            prefix:
                - /phpMyAdmin
                - /phpPgAdmin
                - /phpRedisAdmin
            exact:
                - /api/
server:
  enable: false
EOF'

    # 守護執行程式
    # 安裝 supervisor
    apt install -y supervisor
bash -c 'cat << EOF > /etc/supervisor/conf.d/chrome.conf
[program:chrome]
directory=/usr/bin
command=google-chrome-stable --headless --disable-gpu --remote-debugging-port='${CHROME_PORT}'
numprocs=1
autostart=true
autorestart=true
user=ubuntu
EOF'

bash -c 'cat << EOF > /etc/supervisor/conf.d/rendora.'${RENDORA_CONFIG}'.conf
[program:rendora]
directory=/usr/bin
command=rendora --config '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
numprocs=1
autostart=true
autorestart=true
user=root
EOF'

    # 啟動 supervisor 守護
    supervisorctl update
fi

# 安裝 SSL 憑證
if $installFreeSLL; then
    snap install --classic certbot
    ln -s /snap/bin/certbot /usr/bin/certbot
    certbot --nginx && \
    sed -i "s/listen 443 ssl;/listen 443 ssl http2;/" /etc/nginx/sites-available/${PROJECT}.conf && \
    sed -i "s/443 ssl ipv6only=on;/443 ssl http2 ipv6only=on;/" /etc/nginx/sites-available/${PROJECT}.conf
    systemctl reload nginx
fi