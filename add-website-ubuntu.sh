#!/bin/bash
# 以 sudo 權限執行
# sudo sh ./add-website.sh
# 此腳本會新增 nginx 站點設定檔
# 可選安裝 SSR
# 適用於已經有 LNMP 架構的伺服器

# 專案設定
# 專案名稱 (僅限英數，會以此建立資料夾)
PROJECT=newsite
# 專案網址 (僅限英數，會以此建立 nginx 網站設定檔)
SITE=newsite.com

# 資料庫相關
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
RENDORA_LISTEN_PORT=3002
# ssr 導向 prot
SSR_PROT=8082
# chrmoe 監聽 port，為了多站共通使用請勿改
CHROME_PORT=9222

# 此腳本路徑
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# 更新系統
apt update -y
apt upgrade -y

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

# 建立網站設定檔
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
systemctl reload nginx

# 安裝 SSR
# 判斷有無安裝 chrome
HAS_CHROME=false
if [ "$(which google-chrome-stable)" != "" ]; then
    HAS_CHROME=true
fi

# 判斷有無安裝 redis
HAS_REDIS=false
if [ "$(which redis-cli)" != "" ]; then
    HAS_REDIS=true
fi

# 判斷有無安裝 rendora
HAS_RENDORA=false
if [ "$(which rendora)" != "" ]; then
    HAS_RENDORA=true
fi

# 判斷有無安裝 supervisor
HAS_SUPERVISOR=false
if [ "$(which supervisorctl)" != "" ]; then
    HAS_SUPERVISOR=true
fi

if $INSTALL_SSR; then
    cd $SCRIPT_DIR

    # 安裝 chrome
    if ! $HAS_CHROME; then
        apt install -y make libappindicator1 fonts-liberation gdebi-core
        apt install -f
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        gdebi --non-interactive google-chrome*.deb
    fi

    # 安裝 rendora
    if ! $HAS_RENDORA; then
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
    fi

    # 寫 rendora 設定檔
bash -c 'cat <<\EOF > '${SCRIPT_DIR}'/'${RENDORA_CONFIG}'
debug: false
listen:
    address: 0.0.0.0
    port: '${RENDORA_LISTEN_PORT}'
EOF'
if $HAS_REDIS; then
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
    if ! $HAS_SUPERVISOR; then
        # 安裝 supervisor
        apt install -y supervisor
    fi

    if ! $HAS_CHROME; then
bash -c 'cat << EOF > /etc/supervisor/conf.d/chrome.conf
[program:chrome]
directory=/usr/bin
command=google-chrome-stable --headless --disable-gpu --remote-debugging-port='${CHROME_PORT}'
numprocs=1
autostart=true
autorestart=true
user=ubuntu
EOF'
    fi

bash -c 'cat << EOF > /etc/supervisor/conf.d/rendora.'${RENDORA_CONFIG}'.conf
[program:rendora.'${SITE}']
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