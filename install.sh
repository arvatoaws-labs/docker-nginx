#!/bin/bash
set -e

# build apt cache
apt-get update

# install build dependencies
apt-get install -y gcc g++ make libc6-dev libpcre++-dev libssl-dev libxslt-dev libgd2-xpm-dev libgeoip-dev

# use maximum available processor cores for the build
alias make="make -j$(nproc)"

# download nginx-rtmp-module
if [ ! -f ${NGINX_SETUP_DIR}/nginx-rtmp-module-${RTMP_VERSION}.tar.gz ]; then
  echo "Downloading nginx-rtmp-module-${RTMP_VERSION}..."
  wget https://github.com/pagespeed/nginx-rtmp-module/archive/release-${RTMP_VERSION}.tar.gz -O ${NGINX_SETUP_DIR}/nginx-rtmp-module-${RTMP_VERSION}.tar.gz
fi

echo "Extracting nginx-rtmp-module-${RTMP_VERSION}..."
mkdir ${NGINX_SETUP_DIR}/nginx-rtmp-module
tar -zxf ${NGINX_SETUP_DIR}/nginx-rtmp-module-${RTMP_VERSION}.tar.gz --strip=1 -C ${NGINX_SETUP_DIR}/nginx-rtmp-module
rm -rf ${NGINX_SETUP_DIR}/nginx-rtmp-module-${RTMP_VERSION}.tar.gz

# download ngx_pagespeed
if [ ! -f ${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta.tar.gz ]; then
  echo "Downloading ngx_pagespeed-${NPS_VERSION}..."
  wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.tar.gz -O ${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta.tar.gz
fi

echo "Extracting ngx_pagespeed-${NPS_VERSION}..."
mkdir ${NGINX_SETUP_DIR}/ngx_pagespeed
tar -zxf ${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta.tar.gz --strip=1 -C ${NGINX_SETUP_DIR}/ngx_pagespeed
rm -rf ${NGINX_SETUP_DIR}/ngx_pagespeed-${NPS_VERSION}-beta.tar.gz

# download psol
if [ ! -f ${NGINX_SETUP_DIR}/psol-${NPS_VERSION}.tar.gz ]; then
  echo "Downloading psol-${NPS_VERSION}..."
  wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz -O ${NGINX_SETUP_DIR}/psol-${NPS_VERSION}.tar.gz
fi

echo "Extracting psol-${NPS_VERSION}..."
mkdir ${NGINX_SETUP_DIR}/ngx_pagespeed/psol
tar -zxf ${NGINX_SETUP_DIR}/psol-${NPS_VERSION}.tar.gz --strip=1 -C ${NGINX_SETUP_DIR}/ngx_pagespeed/psol
rm -rf ${NGINX_SETUP_DIR}/psol-${NPS_VERSION}.tar.gz

# download nginx
if [ ! -f ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}.tar.gz ]; then
  echo "Downloading nginx-${NGINX_VERSION}..."
  wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}.tar.gz
fi

echo "Extracting nginx-${NGINX_VERSION}..."
mkdir -p ${NGINX_SETUP_DIR}/nginx
tar -zxf ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}.tar.gz --strip=1 -C ${NGINX_SETUP_DIR}/nginx
rm -rf ${NGINX_SETUP_DIR}/nginx-${NGINX_VERSION}.tar.gz

# build nginx
cd ${NGINX_SETUP_DIR}/nginx

./configure --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --sbin-path=/usr/sbin \
  --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=${NGINX_TEMP_DIR}/body \
  --http-fastcgi-temp-path=${NGINX_TEMP_DIR}/fastcgi \
  --http-proxy-temp-path=${NGINX_TEMP_DIR}/proxy \
  --http-scgi-temp-path=${NGINX_TEMP_DIR}/scgi \
  --http-uwsgi-temp-path=${NGINX_TEMP_DIR}/uwsgi \
  --with-pcre-jit --with-ipv6 --with-http_ssl_module \
  --with-http_stub_status_module --with-http_realip_module \
  --with-http_addition_module --with-http_dav_module --with-http_geoip_module \
  --with-http_gzip_static_module --with-http_image_filter_module \
  --with-http_spdy_module --with-http_sub_module --with-http_xslt_module \
  --with-mail --with-mail_ssl_module \
  --add-module=${NGINX_SETUP_DIR}/nginx-rtmp-module \
  --add-module=${NGINX_SETUP_DIR}/ngx_pagespeed
make && make install

# create default configuration
mkdir -p /etc/nginx/sites-enabled
cat > /etc/nginx/sites-enabled/default <<EOF
server {
  listen 80 default_server;
  listen [::]:80 default_server ipv6only=on;

  root /usr/share/nginx/html;
  index index.html index.htm;

  server_name localhost;

  location / {
    try_files \$uri \$uri/ =404;
  }
}
EOF

# copy rtmp stats template
cp ${NGINX_SETUP_DIR}/nginx-rtmp-module/stat.xsl /usr/share/nginx/html/

# purge build dependencies
apt-get purge -y --auto-remove gcc g++ make libc6-dev libpcre++-dev libssl-dev libxslt-dev libgd2-xpm-dev libgeoip-dev

# cleanup
rm -rf ${NGINX_SETUP_DIR}/{nginx,nginx-rtmp-module,ngx_pagespeed}
rm -rf /var/lib/apt/lists/*