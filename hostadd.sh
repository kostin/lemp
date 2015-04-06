#!/bin/bash

USAGE="To create domains structure and configs you have to use next parameters:\n\t1). Username (lowercase alphabets and digits only, 14 symbols or less). \n\t2). Domain or domains (Ex.: \"test.com test2.com\")."
if [ ! $1 ]; then echo -e $USAGE; exit 0; fi

MYSQLPWD=`cat /root/.mysql-root-password`
USER=$1
HOST=`hostname`

USER_LEN=${#USER}
if [ $USER_LEN -lt 15 ] && ! [[ "$USER" =~ [^a-z0-9\ ] ]]; then
  echo "Username set to $USER. It's OK"
else
  echo "Bad chars in username $USER (must be lowercase alphabets and digits only) or too long username (must be 14 symbols or less)!"
  exit 0
fi

if [ -a /etc/nginx/conf.d/$USER.conf ]; then
  echo "Virtual Host already exists!"
  exit 0
fi

if [ -d /var/www/$USER ]; then
    echo "Directory /var/www/$USER already exists!"
    exit 0
fi

if [ "`grep '$USER:x' /etc/passwd`" ]; then
    echo "User $USER already exists in system!"
    exit 0
fi

if [ -n "$( mysql -u root -p$MYSQLPWD -B -N -e "select * from mysql.user where user = '$USER'" )" ]; then
    echo "MySQL user $USER already exist!"
    exit 0
fi

USRPWD=`pwgen 16 1`
useradd -b /var/www --shell /sbin/nologin --create-home $USER
echo $USRPWD | passwd --stdin $USER
mkdir /var/www/$USER/.hostconf /var/www/$USER/tmp /var/www/$USER/logs /var/www/$USER/dev
usermod -a -G $USER nginx

MAINDB=$USER"_pub"
DEVDB=$USER"_dev"
DBPWD=`pwgen 16 1`
mysql -u root -p$MYSQLPWD -B -N -e "create user '$USER'@'localhost' identified by '$DBPWD'; create database $MAINDB; grant all on $MAINDB.* to '$USER'@'localhost'; create database $DEVDB; grant all on $DEVDB.* to '$USER'@'localhost';"

ALIASES=""
if [ "$2" ]; then
  touch /var/www/$USER/.hostconf/.domains
  for i in $2
  do
    ALIASES="$ALIASES $i www.$i"
    echo $i >> /var/www/$USER/.hostconf/.domains
  done
fi
cp /opt/scripts/nginx-vhost-USERNAME.conf /etc/nginx/conf.d/vhost-$USER.conf
sed -i "s/USERNAME/$USER/g" /etc/nginx/conf.d/vhost-$USER.conf
sed -i "s/ALIASES/$ALIASES/g" /etc/nginx/conf.d/vhost-$USER.conf
sed -i "s/HOSTNAME/$HOST/g" /etc/nginx/conf.d/vhost-$USER.conf

mkdir -p /var/cache/nginx/$USER
chown -R nginx:nginx /var/cache/nginx/$USER

cp /opt/scripts/php-fpm-pool-USERNAME.conf /etc/php-fpm.d/pool-$USER.conf
sed -i "s/USERNAME/$USER/g" /etc/php-fpm.d/pool-$USER.conf
touch /var/www/$USER/logs/php-fpm-slow.log
touch /var/www/$USER/logs/php-fpm-error.log

echo "$USRPWD" > /var/www/$USER/.hostconf/.password-user
echo "$DBPWD" > /var/www/$USER/.hostconf/.password-db

chown -R $USER:$USER /var/www/$USER
chmod 750 /var/www/$USER /var/www/$USER/public /var/www/$USER/dev /var/www/$USER/tmp /var/www/$USER/logs
chown -R root:root /var/www/$USER/.hostconf
chmod -R 400 /var/www/$USER/.hostconf
chmod 500 /var/www/$USER/.hostconf

echo "User password: $USRPWD" 
echo "MySQL password for user $USER: $DBPWD"

/etc/init.d/nginx restart
/etc/init.d/php-fpm restart
