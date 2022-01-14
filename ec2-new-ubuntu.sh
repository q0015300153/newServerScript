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

# SSL 相關
# 是否在本機安裝免費的 SSL 憑證
installFreeSLL=false

# 更新系統
apt update -y
apt upgrade -y
# 設定時區
timedatectl set-timezone Asia/Taipei
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
apt update -y
apt upgrade -y
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
sed -i 's/supervised.*/supervised systemd/' /etc/redis/redis.conf
systemctl restart redis.service
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
rm -f /etc/nginx/sites-available/default
bash -c 'cat <<\EOF > /etc/nginx/sites-available/default
##
# You should look at the following URL'\''s in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# https://www.nginx.com/resources/wiki/start/
# https://www.nginx.com/resources/wiki/start/topics/tutorials/config_pitfalls/
# https://wiki.debian.org/Nginx/DirectoryStructure
#
# In most cases, administrators will remove this file from sites-enabled/ and
# leave it as reference inside of sites-available where it will continue to be
# updated by the nginx packaging team.
#
# This file will automatically load configuration files provided by other
# applications, such as Drupal or Wordpress. These applications will be made
# available underneath a path with that package name, such as /drupal8.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##

# Default server configuration
#
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    # SSL configuration
    #
    # listen 443 ssl default_server;
    # listen [::]:443 ssl default_server;
    #
    # Note: You should disable gzip for SSL traffic.
    # See: https://bugs.debian.org/773332
    #
    # Read up on ssl_ciphers to ensure a secure configuration.
    # See: https://bugs.debian.org/765782
    #
    # Self signed certs generated by the ssl-cert package
    # Don'\''t use them in a production server!
    #
    # include snippets/snakeoil.conf;

    #root "/var/www";
    root "/home/www-data/'${PROJECT}'";

    # Add index.php to the list if you are using PHP
    index index.html index.htm index.nginx-debian.html index.php;

    server_name _;

    #location / {
    #    # First attempt to serve request as file, then
    #    # as directory, then fall back to displaying a 404.
    #    try_files $uri $uri/ =404;
    #}

    # pass PHP scripts to FastCGI server
    #
    #location ~ \.php$ {
    #    include snippets/fastcgi-php.conf;
    #
    #    # With php-fpm (or other unix sockets):
    #    fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    #    # With php-cgi (or other tcp sockets):
    #    fastcgi_pass 127.0.0.1:9000;
    #}

    # deny access to .htaccess files, if Apache'\''s document root
    # concurs with nginx'\''s one
    #
    #location ~ /\.ht {
    #    deny all;
    #}

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
}


# Virtual Host configuration for example.com
#
# You can move that to a different file under sites-available/ and symlink that
# to sites-enabled/ to enable it.
#
#server {
#    listen 80;
#    listen [::]:80;
#
#    server_name example.com;
#
#    root /var/www/example.com;
#    index index.html;
#
#    location / {
#        try_files $uri $uri/ =404;
#    }
#}
EOF'

bash -c 'cat <<\EOF > /etc/nginx/sites-available/'${PROJECT}'.conf
#server {
#    listen 80;
#    server_name '${SITE}' *.'${SITE}';
#    return 308 https://$host$request_uri;
#}

server {
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
ln -s /etc/nginx/sites-available/${PROJECT}.conf /etc/nginx/sites-enabled/${PROJECT}.conf
chmod 777 /etc/nginx/sites-enabled/${PROJECT}.conf
chmod 644 /etc/nginx/sites-available/${PROJECT}.conf
chmod 644 /etc/nginx/sites-available/default
systemctl reload nginx

# 安裝 SSL 憑證
if $installFreeSLL; then
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
certbot --nginx && \
sed -i "s/listen 443 ssl;/listen 443 ssl http2;/" /etc/nginx/sites-available/${PROJECT}.conf && \
sed -i "s/443 ssl ipv6only=on;/443 ssl http2 ipv6only=on;/" /etc/nginx/sites-available/${PROJECT}.conf
systemctl reload nginx
fi