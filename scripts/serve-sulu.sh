#!/usr/bin/env bash

mkdir /etc/nginx/ssl 2>/dev/null
openssl genrsa -out "/etc/nginx/ssl/$1.key" 1024 2>/dev/null
openssl req -new -key /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.csr -subj "/CN=$1/O=Vagrant/C=UK" 2>/dev/null
openssl x509 -req -days 365 -in /etc/nginx/ssl/$1.csr -signkey /etc/nginx/ssl/$1.key -out /etc/nginx/ssl/$1.crt 2>/dev/null

block="server {
    listen ${3:-80};
    listen ${4:-443} ssl;
    server_name $1;
    root \"$2\";

    charset utf-8;

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/$1-ssl-error.log error;

    sendfile off;

    client_max_body_size 100m;

    # DEV
    location ~ ^/(website|admin|app)\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 32;
        fastcgi_buffers 16 16k;
        fastcgi_param SYMFONY_ENV dev;
        fastcgi_param SYMFONY_DEBUG 1;
        # Prevents URIs that include the front controller. This will 404:
        # http://domain.tld/app.php/some-path
        # Remove the internal directive to allow URIs like this
        internal;
    }
    
    # strip app.php/ prefix if it is present
    rewrite ^/app\.php/?(.*)\$ /$1 permanent;

    location /admin {
        index admin.php;
        try_files \$uri @rewriteadmin;
    }

    location @rewriteadmin {
        rewrite ^(.*)\$ /admin.php/$1 last;
    }

    location / {
      index website.php;
      try_files \$uri @rewritewebsite;
    }

    # expire
    location ~* \.(?:ico|css|js|gif|jpe?g|png)\$ {
        try_files \$uri /website.php/$1;
        access_log off;
        expires 30d;
        add_header Pragma public;
        add_header Cache-Control "public";
    }

    location @rewritewebsite {
        rewrite ^(.*)\$ /website.php/$1 last;
    }


    location ~ /\.ht {
        deny all;
    }

    ssl_certificate     /etc/nginx/ssl/$1.crt;
    ssl_certificate_key /etc/nginx/ssl/$1.key;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
service nginx restart
service php7.2-fpm restart
