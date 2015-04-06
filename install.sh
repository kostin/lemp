#!/bin/bash

DLPATH='https://github.com/kostin/lemp/raw/master'

echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
echo 'nameserver 77.88.8.8' >> /etc/resolv.conf

mkdir -p /opt/scripts
cd /opt/scripts
wget --quiet -N $DLPATH/install.sh
wget --quiet -N $DLPATH/hostadd.sh
wget --quiet -N $DLPATH/hostdel.sh
wget --quiet -N $DLPATH/robots.txt
wget --quiet -N $DLPATH/nginx-vhost-USERNAME.conf
wget --quiet -N $DLPATH/php-fpm-pool-USERNAME.conf
chmod u+x /opt/scripts/*.sh

killall -9 httpd
yum -y remove httpd
yum -y install epel-release
sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo

rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

if [ `uname -m` == 'x86_64' ]; then
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
else
cat > /etc/yum.repos.d/MariaDB.repo <<EOF
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.0/centos6-x86
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
fi

yum -y update

yum -y install pwgen screen git mc sysstat
yum -y install MariaDB-server
yum -y install php55w-common php55w-opcache php55w-cli php55w-fpm php55w-gd php55w-mbstring php55w-mcrypt php55w-mysql php55w-pdo php55w-xml
yum -y install nginx16

echo "#!/bin/bash" > /etc/profile.d/php-cli.sh
echo 'alias php="php -c /etc/php-cli.ini"' >> /etc/profile.d/php-cli.sh
echo "magic_quotes_gpc = Off" > /etc/php-cli.ini

cd /etc
wget --quiet -N $DLPATH/php.ini 
touch /var/log/phpmail.log
chmod 666 /var/log/phpmail.log 

service nginx restart
chkconfig nginx on
service php-fpm restart
chkconfig php-fpm on

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

cd /etc
wget --quiet -N $DLPATH/my.cnf 
touch /var/log/mysql-slow.log 
chown mysql:mysql /var/log/mysql-slow.log 
chmod 640 /var/log/mysql-slow.log 
rm -f /var/lib/mysql/ib_logfile* 
rm -f /var/lib/mysql/mysql-bin.*

service mysql restart
chkconfig mysql on

iptables -F
service iptables save
service iptables restart

if [ ! -f /etc/ssl/server.key ] && [ ! -f /etc/ssl/server.crt ]; then
  openssl req -subj '/CN=./O=.' -new -newkey rsa:2048 -days 3650 -nodes -x509 \
  -keyout /etc/ssl/server.key -out /etc/ssl/server.crt
fi

/opt/scripts/hostdel.sh phpma
/opt/scripts/hostdel.sh phpmyadmin
/opt/scripts/hostadd.sh phpmyadmin
cd /var/www/phpma
wget http://sourceforge.net/projects/phpmyadmin/files/phpMyAdmin/4.4.0/phpMyAdmin-4.4.0-all-languages.tar.gz/download \
-O /var/www/phpmyadmin/phpMyAdmin.tar.gz
tar xfzp /var/www/phpmyadmin/phpMyAdmin.tar.gz -C /var/www/phpmyadmin/public --strip-components=1
cp /var/www/phpmyadmin/public/config.sample.inc.php /var/www/phpmyadmin/public/config.inc.php
sed -ri "s/cfg\['blowfish_secret'\] = ''/cfg['blowfish_secret'] = '`pwgen 32 1`'/" /var/www/phpmyadmin/public/config.inc.php

cat /opt/scripts/nginx-vhost-phpMyAdmin.conf > /etc/nginx/conf.d/nginx-vhost-phpmyadmin.conf
HOST=`hostname`
sed -i "s/HOSTNAME/$HOST/g" /etc/nginx/conf.d/nginx-vhost-phpmyadmin.conf
mysql -p$MYSQLPASS -e "drop database 'phpmyadmin_pub'; drop database 'phpmyadmin_dev'; drop user 'phpmyadmin'@'localhost';"
rm -rf /var/www/phpmyadmin/dev
service nginx restart
