#!/bin/bash

PATH=/sbin:/usr/local/sbin:/usr/sbin:/usr/bin:/bin

# ----- Check user Run Script -----
if [ $(id -u) != 0 ]; then
	echo "Error: You Must Be root To Run This Script, su root Please..."
	exit 1
fi

# ------ Check SELinux -----
selinux=$(sestatus | awk '{print $3}')
if [ "$selinux" != "disabled" ]; then
	echo "Error: You Should Disabled The SELinux, See /etc/selinux/config"
	exit 1
fi

# ----- Define -----
YUM="/etc/yum.repos.d"
PHPLOG="/var/log/php"
MYSQLLOG="/var/log/mysql"
SRC="/usr/local/src"
ADMIN="backyard"
CMSTOP="CmsTop_Media_1.7.0.8921_php52.zip"
CURDIR=$(pwd)

# add 163/sohu.repo
if [ -f $YUM/CentOS-Bse-163.repo ]
then :
else
	wget http://mirrors.163.com/.help/CentOS-Base-163.repo -P /tmp
	#wget http://mirrors.sohu.com/help/CentOS-Base-sohu.repo
	mv /tmp/CentOS-Base-163.repo $YUM
fi


# ----- Check The CmsTop -----
if [ ! -f $CURDIR/tar/$CMSTOP ]; then
	echo "Error: Your Tar Don't Have The CmsTop Software ..."
	exit 1
fi

chmod -R 700 $CURDIR/shell

# ----- yum Installing -----
# wget http://mirrors.sohu.com/help/CentOS-Base-sohu.repo
# rpm --import http://mirrors.sohu.com/centos/RPM-GPG-KEY-CentOS-5
yum -y install gcc gcc-c++ autoconf make libtool libXaw dialog expect ntp expat-devel libxml2-devel libevent libevent-devel screen

# ----- Define Extra Yum ----- #
if [ -f $YUM/cmstop.repo ]; then
        mv -f $YUM/cmstop.repo $YUM/cmstop.bak
fi
cp $CURDIR/conf/cmstop.repo $YUM

#yum -y install httpd php php-devel mysql mysql-server mysql-devel memcached
yum -y install httpd mysql55 mysql55-server mysql55-devel php php-devel memcached redis # libmysqlclient15-5.0.77-1.1.w5 depend && auto install perl-DBD-MySQ && when remove mysql-server mysql auto remove perl-DBD-MySQL
# when install mysql55-sever auto install libmysqlclient15 mysql55-libs && when yum remove libmysqlclient15 auto remove mysql-connector-odbc perl-DBD-MySQL php-mysql
# purge remove mysql55 please use --- yum remove libmysqlclient15 mysql55*

if [ `uname -m` == 'x86_64' ]; then
        rpm -ivh $CURDIR/tar/t1lib-5.1.1-7.el5.x86_64.rpm
else
        rpm -ivh $CURDIR/tar/t1lib-5.1.1-7.el5.i386.rpm
fi

yum -y install php-mysql php-mssql php-gd php-xml php-mcrypt php-mbstring php-pear php-snmp php-redis libdbi-dbd-mysql freetds

# ----- Sync Date & time -----
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate us.pool.ntp.org
echo "50 23 * * * /usr/sbin/ntpdate us.pool.ntp.org" >> /var/spool/cron/root

# ----- Input The Directory -----
DIALOG=${DIALOG=dialog}
$DIALOG	--backtitle "Welcome to CmsTop CentOS Install" \
		--title " CmsTop Server Configure Tool " \
		--clear \
        --yesno "Hi friends. This is a CmsTop Server configure tool. \
		We have installed the Apache , MySQL and PHP just a moment \
		ago, now it will help us configuring those options and \
		installing some extensions. \
		Please press 'YES' button to continue..." 10 60
case $? in
	0)
	until [[ $domain =~ "^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9-]{1,62})+" ]]
	do
	domain=`domain 2>/dev/null` || domain=./domain$$
    	trap "rm -f $domain" 0 1 2 5 15
	    $DIALOG --title " Domain Configure " \
		        --clear \
				--inputbox " Please Input The Domain For Your Web Site Such
				As 'cmstop.com'.
				" 10 60 2> $domain
				retval=$?
				case $retval in
					0)
						domain="`cat $domain`";;
				esac
	done
	until [[ $htdocs =~ ^/[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$ ]]
	do
	htdocs=`htdocs 2>/dev/null` || htdocs=./htdocs$$
    	trap "rm -f $htdocs" 0 1 2 5 15
	    $DIALOG --title " Apache Directory Configure " \
		        --clear \
				--inputbox " Please Input The Relative Path For Apache htdocs Such
				As '/www/htdocs'.
				" 10 60 2> $htdocs
				retval=$?
				case $retval in
					0)
						htdocs="`cat $htdocs`";;
				esac
	done
	until [[ $mysql =~ ^/[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*$ ]]
	do
	mysql=`mysql 2>/dev/null` || mysql=./mysql$$
    	trap "rm -f $mysql" 0 1 2 5 15
	    $DIALOG --title " MySQL Data Configure: " \
		        --clear \
				--inputbox " Please Input The Relative Path For MySQL Data \
				Directory Such As '/www/mysql'.
				" 10 60 2> $mysql
				retval=$?
				case $retval in
					0)
						mysql="`cat $mysql`";;
				esac
	done

# ----- Create WWW & MySQL Directory -----
if [ ! -d $mysql ]; then
	mkdir -p $mysql
fi
chown -R mysql:mysql $mysql
chmod 700 $mysql

if [ ! -d $htdocs ]; then
	mkdir -p $htdocs
fi
chown -R root:apache $htdocs

if [ ! -d $PHPLOG ]; then
	mkdir -p $PHPLOG
fi
chown -R apache:apache $PHPLOG

if [ ! -d $MYSQLLOG ]; then
	mkdir -p $MYSQLLOG
fi
chown -R mysql:mysql $MYSQLLOG
chmod 700 $MYSQLLOG
chown -R apache:apache /var/lib/php/session

# ----- Rewrite Apache & MySQL Configure -----
mv -f /etc/my.cnf /etc/my.bak
cp $CURDIR/conf/my.cnf /etc/my.cnf
mv -f /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.bak
cp $CURDIR/conf/httpd.conf /etc/httpd/conf
mkdir /etc/httpd/vhosts
mv -f /etc/php.ini /etc/php.bak
cp $CURDIR/conf/php.ini /etc
cp $CURDIR/conf/info.php $htdocs

sed -i 's#/www/mysql#'$mysql'#g' /etc/my.cnf
sed -i 's#/var/log/mysql#'$MYSQLLOG'#g' /etc/my.cnf
sed -i 's#/www/htdocs#'$htdocs'#g' /etc/httpd/conf/httpd.conf
sed -i 's#/www/htdocs#'$htdocs'#g' /etc/php.ini
sed -i 's#/var/log/php#'$PHPLOG'#g' /etc/php.ini
sed -i 's/AddHandler/#AddHandler/g' /etc/httpd/conf.d/php.conf
sed -i 's/AddType/#AddType/g' /etc/httpd/conf.d/php.conf

#mv /usr/share/mysql/english/errmsg.sys /usr/share/mysql/english/errmsg.backup
#cp $CURDIR/conf/errmsg.sys /usr/share/mysql/english/errmsg.sys
/etc/init.d/mysqld start

cd $CURDIR/tar

# ----- Zend Extensions -----
if [ `uname -m` = 'x86_64' ]; then
	if [ ! -f ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz ]; then
	    wget http://mirrors.cmstop/cmstop/ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz
	fi
	tar xvzf ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz -C $SRC
	cp $SRC/ZendOptimizer-3.3.9-linux-glibc23-x86_64/data/5_2_x_comp/ZendOptimizer.so /usr/lib64/php/modules/ZendOptimizer.so
	sed -i 's#usr/lib/php/modules#usr/lib64/php/modules#g' /etc/php.ini
else
	if [ ! -f ZendOptimizer-3.3.9-linux-glibc23-i386.tar.gz ]; then
	    wget http://mirrors.cmstop/cmstop/ZendOptimizer-3.3.9-linux-glibc23-i386.tar.gz
	fi
	tar xvzf ZendOptimizer-3.3.9-linux-glibc23-i386.tar.gz -C $SRC
	cp $SRC/ZendOptimizer-3.3.9-linux-glibc23-i386/data/5_2_x_comp/ZendOptimizer.so /usr/lib/php/modules/ZendOptimizer.so
fi

# ----- Copy vhosts conf -----
cp $CURDIR/conf/cmstop.apache.conf /etc/httpd/vhosts/$domain.conf
sed -i 's#/www/htdocs#'$htdocs'#g' /etc/httpd/vhosts/$domain.conf
sed -i 's#admin.cmstop#'$ADMIN'.cmstop#g' /etc/httpd/vhosts/$domain.conf
sed -i 's#cmstop.loc#'$domain'#g' /etc/httpd/vhosts/$domain.conf

# ----- Copy Mobile Detect conf -----
cp $CURDIR/conf/cmstop.apache.mobile-detect.inc /etc/httpd/vhosts/$domain.mobile-detect.inc
sed -i 's#cmstop.loc#'$domain'#g' /etc/httpd/vhosts/$domain.mobile-detect.inc

# ----- Tar The Extensions -----
if [ ! -f scws-1.1.5.tar.bz2 ]; then
    wget http://mirrors.cmstop/cmstop/scws-1.1.5.tar.bz2
fi
if [ ! -f scws-dict-chs-utf8.tar.bz2 ]; then
    wget http://mirrors.cmstop/cmstop/scws-dict-chs-utf8.tar.bz2
fi
if [ ! -f coreseek-3.2.13.tar.gz ]; then
    wget http://mirrors.cmstop/cmstop/coreseek-3.2.13.tar.gz
fi

# ---- bzip2 check ----
bzip2 -h > /dev/nulll 2>&1
if [ $? = 0 ]
then :
else
	echo "faild. not installed"
	sleep 3
	yum -y install bzip2
fi

tar xvjf scws-1.1.5.tar.bz2 -C $SRC
tar xvjf scws-dict-chs-utf8.tar.bz2 -C $SRC
tar xvzf coreseek-3.2.13.tar.gz -C $SRC

# ------ SCWS Installing -----
cd $SRC/scws-1.1.5
./configure --prefix=/usr/local/scws
make
make install
cd phpext
phpize
./configure --with-scws=/usr/local/scws
make
make install
cp $SRC/dict.utf8.xdb /usr/local/scws/etc
chmod 644 -R /usr/local/scws/etc/*

# ----- memcache.so Installing -----
$CURDIR/shell/memcache.sh

# ----- Sphinx Installing -----
cd $SRC/coreseek-3.2.13/mmseg-3.2.13
./bootstrap
./configure --prefix=/usr/local/mmseg
make
make install
cd ../csft-3.2.13
./configure --prefix=/usr/local/coreseek --with-mmseg --with-mmseg-includes=/usr/local/mmseg/include/mmseg --with-mmseg-libs=/usr/local/mmseg/lib
make
make install
mkdir -p /var/lib/sphinx
mkdir -p /var/run/sphinx
mkdir -p /var/log/sphinx
cp $CURDIR/conf/csft.conf /usr/local/coreseek/etc/csft.conf
cd $SRC/coreseek-3.2.13/csft-3.2.13/api/libsphinxclient/
./buildconf.sh
./configure
make
make install

# ---- unzip checking ----�
if unzip -v > /dev/null 2>&1
then :
else
	echo "failed, not installd"
	sleep 3
	echo "now install ..."
	yum -y install unzip
fi

# ----- CmsTop Installing -----
cd $CURDIR/tar
mkdir $htdocs/cmstop
unzip $CMSTOP -d $htdocs/cmstop
chown -R root:apache $htdocs/cmstop
find $htdocs/cmstop -type d | xargs chmod 755
find $htdocs/cmstop -type f | xargs chmod 644
chmod -R 777 $htdocs/cmstop/data
chmod -R 777 $htdocs/cmstop/public/www
chmod 777 $htdocs/cmstop/public/upload
chmod -R 777 $htdocs/cmstop/public/img/apps/special/templates
chmod -R 777 $htdocs/cmstop/public/img/apps/special/scheme
chmod -R 777 $htdocs/cmstop/templates
sed -i 's#cmstop.loc#'$domain'#g' `grep cmstop\.loc -rl --exclude=notes.xml $htdocs/cmstop`
sed -i 's#admin#'$ADMIN'#g' $htdocs/cmstop/config/define.php

# use random string replace authkey
authkey=
for ((i = 0; i < 15; i++)); do
    tmpkey=`cat /dev/urandom | sed 's/[^a-zA-Z0-9]//g' | strings -n 2 | head -1`
    authkey=${authkey}${tmpkey}
done
sed -i "s#'authkey' => '\(.*\)'#'authkey' => '$authkey'#g" $htdocs/cmstop/config/config.php

# ---- phpMyAdmin Installing -----
cd $CURDIR/tar
if [ ! -f phpMyAdmin-3.3.10-all-languages.zip ]; then
    wget http://mirrors.cmstop/cmstop/phpMyAdmin-3.3.10-all-languages.zip
fi
mkdir $htdocs/dbpma
unzip phpMyAdmin-3.3.10-all-languages.zip -d $htdocs/dbpma
chown -R root:apache $htdocs/dbpma
cp $CURDIR/conf/dbpma.apache.conf /etc/httpd/vhosts/dbpma.conf
sed -i 's#/www/htdocs#'$htdocs'#g' /etc/httpd/vhosts/dbpma.conf
sed -i 's#cmstop.loc#'$domain'#g' /etc/httpd/vhosts/dbpma.conf

# ------ CmsTop Crond -----
echo "0 2 * * *  /usr/local/coreseek/bin/indexer  --all --rotate" >> /var/spool/cron/root
echo "*/10 * * * * /usr/local/coreseek/bin/indexer addcontent --rotate" >> /var/spool/cron/root
echo "*/1 * * * * /bin/bash $htdocs/cmstop/cron/cron_cmstop.sh >>  /var/log/cmstop_cron.log" >> /var/spool/cron/root
echo "*/1 * * * * /usr/bin/php $htdocs/cmstop/cron/mail.php >>  /var/log/cmstop_mail.log" >> /var/spool/cron/root

# ----- Startup And Backup -----
chkconfig httpd on
chkconfig mysqld on
chkconfig memcached on
chkconfig redis on
echo "ulimit -SHn 51200" >> /etc/rc.local
echo "/usr/local/coreseek/bin/searchd" >> /etc/rc.local
cp $CURDIR/shell/cmstop_backup.sh /usr/local/sbin
sed -i 's#/www/htdocs#'$htdocs'#g' /usr/local/sbin/cmstop_backup.sh
sed -i 's#/www/mysql#'$mysql'#g' /usr/local/sbin/cmstop_backup.sh
chmod 700 /usr/local/sbin/cmstop_backup.sh
echo "30 2 * * * /bin/bash /usr/local/sbin/cmstop_backup.sh" >> /var/spool/cron/root


# ----- Import CmsTop SQL -----
mysqladmin -uroot CREATE cmstop;
mysql -uroot cmstop < $htdocs/cmstop/cmstop.sql
/usr/local/coreseek/bin/indexer --all

/etc/init.d/crond restart
/etc/init.d/httpd start
/etc/init.d/memcached start
/etc/init.d/redis start
/usr/local/coreseek/bin/searchd
/etc/init.d/httpd restart

# echo MySQL anonymous user
mysql -u user -e "system echo -e '\033[41m Oh.. Do not forgot delete/remove MySQL anonymous user \033[0m \n installation script run over now..'";
		;;
  1)
    echo " Thanks For Choosing CmsTop ! ";;
  255)
    echo " Thanks For Choosing CmsTop ! ";;
esac
