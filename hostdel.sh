#!/bin/bash

usage="To remove user you need to use next parameters:\n\t1). Username. \nFor example:\n\t$0 testuser"
if [ ! $1 ]; then echo -e $usage; exit 0; fi

MYSQLPWD=`cat /root/.mysql-root-password`
DATE=`date +%Y-%m-%d_%H-%M`
USER=$1
STORE_DIR='/backups/.deleted'
mkdir -p STORE_DIR

for DB in `mysql -p$MYSQLPWD -B -N -e "select Db from mysql.db where user = '$USER'"`
do
  mysqldump -u root -p$MYSQLPWD $DB | gzip > $STORE_DIR/$DB-db-$DATE.sql.gz
  mysql -u root -p$MYSQLPWD -e "drop database $DB;"
done

if test -n "$( mysql -u root -p$MYSQLPWD -B -N -e "select * from mysql.user where User = '$USER'" )" ; then
  mysql -u root -p$MYSQLPWD -e "drop user '$USER'@'localhost'"
fi

rm -f /etc/nginx/conf.d/vhost-$USER.conf
rm -f /etc/php-fpm.d/pool-$USER.conf
/etc/init.d/nginx restart
/etc/init.d/php-fpm restart
rm -rf /var/cache/nginx/$USER

if [ ! -d /var/www/$USER ]
then
  echo "Directory /var/www/$USER not exist!"
  exit 0
else 
  tar cfzp $STORE_DIR/$USER-$DATE-files.tar.gz /var/www/$USER
  killall -9 -u $USER
  userdel -r $USER
  rm -rf /var/www/$USER
fi
