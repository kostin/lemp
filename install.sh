#!/bin/bash

source $(dirname $0)/conf.sh

echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'nameserver 77.88.8.8' >> /etc/resolv.conf

iptables -F
service iptables save
service iptables restart

ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime

yum -y update
yum -y install epel-release
yum -y install rsync unzip pwgen screen git mc sysstat lshell nano curl

mkdir -p ${SCRPATH} /var/www
wget --no-check-certificate -O /tmp/master.zip ${DLPATH}
cd /tmp
unzip -o master.zip
rsync -a /tmp/lemp6-master/ ${SCRPATH}/
chmod u+x ${SCRPATH}/*.sh 

cp ${SCRPATH}/etc/lshell.conf /etc/lshell.conf

killall -9 httpd
yum -y remove httpd

sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo

rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

if [ `uname -m` == 'x86_64' ]; then
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
else
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos6-x86
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
fi

yum -y install MariaDB-server

cp ${SCRPATH}/etc/my.cnf /etc/my.cnf 
rm -f /var/lib/mysql/ib_logfile* 
rm -f /var/lib/mysql/mysql-bin.*

service mysql restart
chkconfig mysql on

if [ -f /root/.mysql-root-password ]; then 
  MYSQLPASS=`cat /root/.mysql-root-password`	
  echo 'MySQL root password already set up'
else
  MYSQLPASS=`pwgen 24 1`
  echo $MYSQLPASS > /root/.mysql-root-password
  echo "MySQL root password is $MYSQLPASS and it stored in /root/.mysql-root-password"
  mysqladmin -u root password $MYSQLPASS
  mysql -p$MYSQLPASS -B -N -e "drop database test"	
fi

rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

yum -y install php55w-common php55w-opcache php55w-cli php55w-fpm php55w-gd php55w-mbstring \
  php55w-mcrypt php55w-mysql php55w-pdo php55w-xml php55w-soap

echo "#!/bin/bash" > /etc/profile.d/php-cli.sh
echo 'alias php="php -c /etc/php-cli.ini"' >> /etc/profile.d/php-cli.sh
echo "magic_quotes_gpc = Off" > /etc/php-cli.ini

cp ${SCRPATH}/etc/php.ini /etc/php.ini 
touch /var/log/phpmail.log
chmod 666 /var/log/phpmail.log 

cp ${SCRPATH}/etc/host.logrotate /etc/logrotate.d/host.logrotate

service php-fpm restart
chkconfig php-fpm on

cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/6/\$basearch/
gpgcheck=0
enabled=1
EOF

yum -y install nginx

cp ${SCRPATH}/etc/nginx.conf /etc/nginx/nginx.conf
mkdir -p /etc/nginx/templates
cp -a ${SCRPATH}/templates/nginx/* /etc/nginx/templates/

service nginx restart
chkconfig nginx on

if [ ! -f /etc/ssl/server.key ] && [ ! -f /etc/ssl/server.crt ]; then
  openssl req -subj '/CN=./O=.' -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -keyout /etc/ssl/server.key -out /etc/ssl/server.crt
fi

${SCRPATH}/hostdel.sh phpmyadmin
${SCRPATH}/hostadd.sh phpmyadmin

wget http://sourceforge.net/projects/phpmyadmin/files/phpMyAdmin/4.4.0/phpMyAdmin-4.4.0-all-languages.tar.gz/download \
-O /tmp/phpMyAdmin.tar.gz
tar xfzp /tmp/phpMyAdmin.tar.gz -C /var/www/phpmyadmin/public --strip-components=1
cp /var/www/phpmyadmin/public/config.sample.inc.php /var/www/phpmyadmin/public/config.inc.php
sed -ri "s/cfg\['blowfish_secret'\] = ''/cfg['blowfish_secret'] = '`pwgen 32 1`'/" /var/www/phpmyadmin/public/config.inc.php

cat ${SCRPATH}/templates/nginx-vhost-phpMyAdmin.conf > /etc/nginx/conf.d/nginx-vhost-phpmyadmin.conf
HOST=`hostname`
sed -i "s/HOSTNAME/${HOST}/g" /etc/nginx/conf.d/nginx-vhost-phpmyadmin.conf
mysql -p$MYSQLPASS -e "drop database phpmyadmin_pub; drop database phpmyadmin_dev; drop user 'phpmyadmin'@'localhost';"
rm -rf /var/www/phpmyadmin/dev
service nginx restart

yum -y install postfix
yum -y remove sendmail
setsebool -P httpd_can_sendmail 1
setsebool -P httpd_can_network_connect 1
chkconfig postfix on
service postfix restart
