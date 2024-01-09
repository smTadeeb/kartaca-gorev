kartaca_user:
  user.present:
    - name: kartaca
    - uid: 2023
    - gid: 2023
    - home: /home/krt
    - shell: /bin/bash
    - createhome: True
    - password: {{ salt['pillar.get']('user_passwords:kartaca')  }}
    - unless: id -u kartaca

sudo_privileges:
  file.append:
    - name: /etc/sudoers
    - text: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/yum"

set_timezone:
  timezone.system:
    - name: Europe/Istanbul

enable_ip_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1
    - config: /etc/sysctl.conf


{% set package_list = ['htop', 'tcpdump', 'traceroute', 'ping', 'dig', 'iostat', 'mtr'] %}
{% if grains['os'] == 'Ubuntu' %}
install_packages:
  pkg.installed:
    - names: {{ package_list }}
{% elif grains['os'] == 'CentOS' %}
install_packages:
  pkg.installed:
    - names: {{ package_list }}
{% endif %}


{% set subnet_ips = ['192.168.168.128', '192.168.168.129', '192.168.168.130', '192.168.168.131', '192.168.168.132', '192.168.168.133', '192.168.168.134', '192.168.168.135', '192.168.168.136', '192.168.168.137', '192.168.168.138', '192.168.168.139', '192.168.168.140', '192.168.168.141', '192.168.168.142', '192.168.168.143'] %}
{% for ip in subnet_ips %}
hosts_file_{{ loop.index }}:
  host.present:
    - ip: {{ ip }}
    - names:
      - kartaca.local
    - clean: True
{% endfor %}



{% if grains['os'] == 'CentOS' %}

add_hashicorp_repo:
  cmd.run:
    - name: |
        wget -O- https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo | tee /etc/yum.repos.d/hashicorp.repo
        sudo dnf makecache

install_terraform:
  pkg.installed:
    - name: terraform
    - version: 1.6.4


install_nginx:
  pkg.installed:
    - name: nginx
  service.running:
    - name: nginx
    - enable: True
    - watch:
      - pkg: nginx

php-install:
  pkg.installed:
    - pkgs:
      - php
      - libapache2-mod-php 
      - php-mysql
      - php-curl 
      - php-gd 
      - php-mbstring 
      - php-xml 
      - php-xmlrpc 
      - php-soap 
      - php-intl 
      - php-zip

download_wordpress:
  cmd.run:
    - name: "wget -P /tmp/ https://wordpress.org/latest.tar.gz"
    - unless: test -f /tmp/latest.tar.gz

{% set wordpress_extract_path = '/var/www/wordpress2023' %}
extract_wordpress:
  cmd.run:
    - name: "tar -C /var/www/wordpress2023/ -xzvf /tmp/latest.tar.gz"
    - unless: "test -d {{ wordpress_extract_path }}"

reload_nginx:
  cmd.run:
    - name: "systemctl reload nginx"
    - watch:
      - file: /etc/nginx/nginx.conf
      
configure_wp_config_db:
  cmd.run:
    - name: |
        sed -i "s/database_name_here/{{ salt['pillar.get']('mysql:db_name', {}) }}/g; s/username_here/{{ salt['pillar.get']('mysql:db_user', {} ) }}/g; s/password_here/{{ salt['pillar.get']('mysql:db_password', {} ) }}/g" /var/www/wordpress2023/wp-config.php

get_wp_secrets:
  pkg.installed:
    - name: curl
  cmd.run:
    - name: |
        secrets=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
        sed -i -e "/'AUTH_KEY'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'SECURE_AUTH_KEY'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'LOGGED_IN_KEY'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'NONCE_KEY'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'AUTH_SALT'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'SECURE_AUTH_SALT'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'LOGGED_IN_SALT'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" \
               -e "/'NONCE_SALT'/s/put your unique phrase here/$(echo $secrets | sed 's/\//\\\//g' | awk -F"'" '{print $2}')/" /var/www/wordpress2023/wp-config.php


create_ssl_certificate:
  cmd.run:
    - name: openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
    - require:
      - pkg: install_packages

manage_nginx_config:
  file.managed:
    - name: /etc/nginx/nginx.conf
    - source: salt://etc/nginx/nginx.conf

create_nginx_restart_cron:
  cron.present:
    - name: nginx_restart
    - user: root
    - minute: 0
    - hour: 0
    - daymonth: 1
    - cmd: "systemctl restart nginx"

configure_logrotate:
  file.managed:
    - name: /etc/logrotate.d/nginx
    - source: salt://files/nginx.logrotate


{% elif grains['os'] == 'Ubuntu' %}
   
add_hashicorp_repo:
  cmd.run:
    - name: |
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
        apt update


install_terraform:
  pkg.installed:
    - name: terraform
    - version: 1.6.4



install_gnupg:
  pkg.installed:
    - names:
      - gnupg

download_mysql_deb:
  cmd.run:
    - name: wget https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb -P /tmp

install_mysql_deb:
  cmd.run:
    - name: dpkg -i /tmp/mysql-apt-config_0.8.29-1_all.deb
    - require:
      - cmd: download_mysql_deb

update_packages:
  cmd.run:
    - name: apt-get update
    - require:
      - cmd: install_mysql_deb

install_mysql:
  pkg.installed:
    - names:
      - mysql-server
    - require:
      - cmd: update_packages




configure_mysql_autostart:
  service.running:
    - name: mysql
    - enable: True
    - require:
      - pkg: install_mysql


{% set mysql_db_name = salt['pillar.get']('mysql:db_name') %}
{% set mysql_db_user = salt['pillar.get']('mysql:db_user') %}
{% set mysql_db_password = salt['pillar.get']('mysql:db_password') %}

# Create MySQL database
create-mysql-db:
  mysql_database.present:
    - name: {{ mysql_db_name }}

# Create MySQL user
create-mysql-user:
  mysql_user.present:
    - name: {{ mysql_db_user }}
    - host: localhost
    - password: {{ mysql_db_password }}
    - require:
      - create-mysql-db

# Grant privileges to MySQL user
grant-mysql-privileges:
  mysql_grants.present:
    - grant: ALL PRIVILEGES
    - database: {{ mysql_db_name }}.*
    - user: {{ mysql_db_user }}
    - require:
      - create-mysql-user


backup-cron-job:
  cron.present:
    - name: mysqldump -u {{ salt['pillar.get']('mysql:db_user', {}) }} -p'{{ salt['pillar.get']('mysql:db_password', {}) }}' {{ salt['pillar.get']('mysql:db_name', {}) }} > /backup/db_backup_$(date +\%Y\%m\%d).sql
    - user: root
    - minute: 0
    - hour: 2

{% endif %}