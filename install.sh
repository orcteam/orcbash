#!/bin/bash
# install php 7, mysql 5.5, redis, java 8, maven, htop, swap
# license: Free
# author vo uu 
# group VHB_Sys

# kiem tra thong so server
yum -y install gawk bc wget lsof

clear
printf "=========================================================================\n"
printf "Chung ta se kiem tra cac thong so VPS cua ban de dua ra cai dat hop ly \n"
printf "=========================================================================\n"

cpu_name=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
cpu_cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
cpu_freq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
server_ram_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
server_ram_mb=`echo "scale=0;$server_ram_total/1024" | bc`
server_hdd=$( df -h | awk 'NR==2 {print $2}' )
server_swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
server_swap_mb=`echo "scale=0;$server_swap_total/1024" | bc`
server_ip=$(curl -s $script_root/ip/)

printf "=========================================================================\n"
printf "Thong so server cua ban nhu sau \n"
printf "=========================================================================\n"
echo "Loai CPU : $cpu_name"
echo "Tong so CPU core : $cpu_cores"
echo "Toc do moi core : $cpu_freq MHz"
echo "Tong dung luong RAM : $server_ram_mb MB"
echo "Tong dung luong swap : $server_swap_mb MB"
echo "Tong dung luong o dia : $server_hdd GB"
echo "IP cua server la : $server_ip"
printf "=========================================================================\n"
printf "=========================================================================\n"

# check update

yum -y update

# cai dat php
printf "Ban hay lua chon phien ban PHP muon su dung:\n"
prompt="Nhap vao lua chon cua ban [1-3]: "
php_version="7.1"; # Default PHP 7.1
options=("PHP 7.1" "PHP 7.0" "PHP 5.6")
PS3="$prompt"
select opt in "${options[@]}"; do 

    case "$REPLY" in
    1) php_version="7.1"; break;;
    2) php_version="7.0"; break;;
    3) php_version="5.6"; break;;
    $(( ${#options[@]}+1 )) ) printf "\nHe thong se cai dat PHP 7.1\n"; break;;
    *) printf "Ban nhap sai, he thong cai dat PHP 7.1\n"; break;;
    esac
    
done

# them domain quan ly
printf "\nNhap vao ten mien chinh (non-www hoac www) roi an [ENTER]: " 
read server_name
if [ "$server_name" == "" ]; then
	server_name="xhydra.com"
	echo "Ban nhap sai, he thong dung xhydra.com lam ten mien chinh"
fi

yum -y remove mysql* php* httpd* sendmail* postfix* rsyslog*
yum clean all
yum -y update

clear
printf "=========================================================================\n"
printf "Chuan bi xong, bat dau cai dat server... \n"
printf "=========================================================================\n"
sleep 3

rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
rpm -Uvh https://mirror.webtatic.com/yum/el6/latest.rpm

yum -y install php70w php70w-opcache
yum -y  install php70w-fpm php70w-opcache php70w-fpm php70w-mysql php70w-mysqlnd php70w-pecl-redis php70w-pgsql 

# if [ "$php_version" = "7.1" ]; then
	# yum-config-manager --enable remi-php71
	# yum -y install nginx php-fpm php-common php-gd php-mysqlnd php-pdo php-xml php-mbstring php-mcrypt php-curl php-opcache php-cli php-pecl-zip
# elif [ "$php_version" = "7.0" ]; then
# 	yum-config-manager --enable remi-php70
# 	yum -y install nginx php-fpm php-common php-gd php-mysqlnd php-pdo php-xml php-mbstring php-mcrypt php-curl php-opcache php-cli php-pecl-zip
# elif [ "$php_version" = "5.6" ]; then
# 	yum-config-manager --enable remi-php56
# 	yum -y install nginx php-fpm php-common php-gd php-mysqlnd php-pdo php-xml php-mbstring php-mcrypt php-curl php-opcache php-cli
# elif [ "$php_version" = "5.5" ]; then
# 	yum-config-manager --enable remi-php55
# 	yum -y install nginx php-fpm php-common php-gd php-mysqlnd php-pdo php-xml php-mbstring php-mcrypt php-curl php-opcache php-cli
# else
# 	yum -y install nginx php-fpm php-common php-gd php-mysqlnd php-pdo php-xml php-mbstring php-mcrypt php-curl php-devel php-cli gcc
# fi

# Install Others
yum -y install exim syslog-ng syslog-ng-libdbi cronie fail2ban unzip zip nano openssl ntpdate

# Autostart
chkconfig --add nginx
chkconfig --levels 235 nginx on
chkconfig --add php-fpm
chkconfig --levels 235 php-fpm on
chkconfig --add exim
chkconfig --levels 235 exim on
chkconfig --add syslog-ng
chkconfig --levels 235 syslog-ng on
chkconfig --add fail2ban
chkconfig --levels 23 fail2ban on

#service exim start
#service syslog-ng start

mkdir -p /home/$server_name/public_html
mkdir /home/$server_name/private_html
mkdir /home/$server_name/logs
chmod 777 /home/$server_name/logs


mkdir -p /var/log/nginx
chown -R nginx:nginx /var/log/nginx
chown -R nginx:nginx /var/lib/php/session

wget -q $script_url/html/index.html -O /home/$server_name/public_html/index.html

service nginx start
service php-fpm start
service mysql start

# PHP #
phplowmem='2097152'
check_phplowmem=$(expr $server_ram_mb \< $phplowmem)
max_children=`echo "scale=0;$server_ram_mb*0.4/30" | bc`

if [ "$check_phplowmem" == "1" ]; then
	lessphpmem=y
fi

if [[ "$lessphpmem" = [yY] ]]; then  
	# echo -e "\nCopying php-fpm-min.conf /etc/php-fpm.d/www.conf\n"
	wget -q $script_root/config/php-fpm/php-fpm-min.conf -O /etc/php-fpm.conf
	wget -q $script_root/config/php-fpm/www-min.conf -O /etc/php-fpm.d/www.conf
else
	# echo -e "\nCopying php-fpm.conf /etc/php-fpm.d/www.conf\n"
	wget -q $script_root/config/php-fpm/php-fpm.conf -O /etc/php-fpm.conf
	wget -q $script_root/config/php-fpm/www.conf -O /etc/php-fpm.d/www.conf
fi # lessphpmem

sed -i "s/server_name_here/$server_name/g" /etc/php-fpm.conf
sed -i "s/server_name_here/$server_name/g" /etc/php-fpm.d/www.conf
sed -i "s/max_children_here/$max_children/g" /etc/php-fpm.d/www.conf

# dynamic PHP memory_limit calculation
if [[ "$server_ram_total" -le '262144' ]]; then
	php_memorylimit='48M'
	php_uploadlimit='48M'
	php_realpathlimit='256k'
	php_realpathttl='14400'
elif [[ "$server_ram_total" -gt '262144' && "$server_ram_total" -le '393216' ]]; then
	php_memorylimit='96M'
	php_uploadlimit='96M'
	php_realpathlimit='320k'
	php_realpathttl='21600'
elif [[ "$server_ram_total" -gt '393216' && "$server_ram_total" -le '524288' ]]; then
	php_memorylimit='128M'
	php_uploadlimit='128M'
	php_realpathlimit='384k'
	php_realpathttl='28800'
elif [[ "$server_ram_total" -gt '524288' && "$server_ram_total" -le '1049576' ]]; then
	php_memorylimit='160M'
	php_uploadlimit='160M'
	php_realpathlimit='384k'
	php_realpathttl='28800'
elif [[ "$server_ram_total" -gt '1049576' && "$server_ram_total" -le '2097152' ]]; then
	php_memorylimit='256M'
	php_uploadlimit='256M'
	php_realpathlimit='384k'
	php_realpathttl='28800'
elif [[ "$server_ram_total" -gt '2097152' && "$server_ram_total" -le '3145728' ]]; then
	php_memorylimit='320M'
	php_uploadlimit='320M'
	php_realpathlimit='512k'
	php_realpathttl='43200'
elif [[ "$server_ram_total" -gt '3145728' && "$server_ram_total" -le '4194304' ]]; then
	php_memorylimit='512M'
	php_uploadlimit='512M'
	php_realpathlimit='512k'
	php_realpathttl='43200'
elif [[ "$server_ram_total" -gt '4194304' ]]; then
	php_memorylimit='800M'
	php_uploadlimit='800M'
	php_realpathlimit='640k'
	php_realpathttl='86400'
fi

cat > "/etc/php.d/00-hocvps-custom.ini" <<END
date.timezone = Asia/Ho_Chi_Minh
max_execution_time = 180
short_open_tag = On
realpath_cache_size = $php_realpathlimit
realpath_cache_ttl = $php_realpathttl
memory_limit = $php_memorylimit
upload_max_filesize = $php_uploadlimit
post_max_size = $php_uploadlimit
expose_php = Off
mail.add_x_header = Off
max_input_nesting_level = 128
max_input_vars = 2000
mysqlnd.net_cmd_buffer_size = 16384
always_populate_raw_post_data=-1
disable_functions=shell_exec
END

# Nginx #
cat > "/etc/nginx/nginx.conf" <<END

user  nginx;
worker_processes  $cpu_cores;
worker_rlimit_nofile 260000;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
	worker_connections  2048;
	accept_mutex off;
	accept_mutex_delay 200ms;
	use epoll;
	#multi_accept on;
}

http {
	include       /etc/nginx/mime.types;
	default_type  application/octet-stream;

	log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
	              '\$status \$body_bytes_sent "\$http_referer" '
	              '"\$http_user_agent" "\$http_x_forwarded_for"';
		      
	#Disable IFRAME
	add_header X-Frame-Options SAMEORIGIN;
	
	#Prevent Cross-site scripting (XSS) attacks
	add_header X-XSS-Protection "1; mode=block";
	
	#Prevent MIME-sniffing
	add_header X-Content-Type-Options nosniff;
	
	access_log  off;
	sendfile on;
	tcp_nopush on;
	tcp_nodelay off;
	types_hash_max_size 2048;
	server_tokens off;
	server_names_hash_bucket_size 128;
	client_max_body_size 0;
	client_body_buffer_size 256k;
	client_body_in_file_only off;
	client_body_timeout 60s;
	client_header_buffer_size 256k;
	client_header_timeout  20s;
	large_client_header_buffers 8 256k;
	keepalive_timeout 10;
	keepalive_disable msie6;
	reset_timedout_connection on;
	send_timeout 60s;

	gzip on;
	gzip_static on;
	gzip_disable "msie6";
	gzip_vary on;
	gzip_proxied any;
	gzip_comp_level 6;
	gzip_buffers 16 8k;
	gzip_http_version 1.1;
	gzip_types text/plain text/css application/json text/javascript application/javascript text/xml application/xml application/xml+rss;

	include /etc/nginx/conf.d/*.conf;
}
END

cat > "/usr/share/nginx/html/403.html" <<END
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>hocvps-nginx</center>
</body>
</html>
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
END

cat > "/usr/share/nginx/html/404.html" <<END
<html>
<head><title>404 Not Found</title></head>
<body bgcolor="white">
<center><h1>404 Not Found</h1></center>
<hr><center>hocvps-nginx</center>
</body>
</html>
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
<!-- a padding to disable MSIE and Chrome friendly error page -->
END

rm -rf /etc/nginx/conf.d/*
> /etc/nginx/conf.d/default.conf

server_name_alias="www.$server_name"
if [[ $server_name == *www* ]]; then
    server_name_alias=${server_name/www./''}
fi

cat > "/etc/nginx/conf.d/$server_name.conf" <<END
server {
	listen 80;
	
	server_name $server_name_alias;
	rewrite ^(.*) http://$server_name\$1 permanent;
}

server {
	listen 80 default_server;
		
	# access_log off;
	access_log /home/$server_name/logs/access.log;
	# error_log off;
    	error_log /home/$server_name/logs/error.log;
	
    	root /home/$server_name/public_html;
	index index.php index.html index.htm;
    	server_name $server_name;
 
    	location / {
		try_files \$uri \$uri/ /index.php?\$args;
	}
	
	# Custom configuration
	include /home/$server_name/public_html/*.conf;
 
    	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
        	include /etc/nginx/fastcgi_params;
        	fastcgi_pass 127.0.0.1:9000;
        	fastcgi_index index.php;
		fastcgi_connect_timeout 1000;
		fastcgi_send_timeout 1000;
		fastcgi_read_timeout 1000;
		fastcgi_buffer_size 256k;
		fastcgi_buffers 4 256k;
		fastcgi_busy_buffers_size 256k;
		fastcgi_temp_file_write_size 256k;
		fastcgi_intercept_errors on;
        	fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    	}
	
	location /nginx_status {
  		stub_status on;
  		access_log   off;
		allow 127.0.0.1;
		allow $server_ip;
		deny all;
	}
	
	location /php_status {
		fastcgi_pass 127.0.0.1:9000;
		fastcgi_index index.php;
		fastcgi_param SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
		include /etc/nginx/fastcgi_params;
		allow 127.0.0.1;
		allow $server_ip;
		deny all;
    	}
	
	# Disable .htaccess and other hidden files
	location ~ /\.(?!well-known).* {
		deny all;
		access_log off;
		log_not_found off;
	}
	
        location = /favicon.ico {
                log_not_found off;
                access_log off;
        }
	
	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}
	
	location ~* \.(3gp|gif|jpg|jpeg|png|ico|wmv|avi|asf|asx|mpg|mpeg|mp4|pls|mp3|mid|wav|swf|flv|exe|zip|tar|rar|gz|tgz|bz2|uha|7z|doc|docx|xls|xlsx|pdf|iso|eot|svg|ttf|woff)$ {
	        gzip_static off;
		add_header Pragma public;
		add_header Cache-Control "public, must-revalidate, proxy-revalidate";
		access_log off;
		expires 30d;
		break;
        }

        location ~* \.(txt|js|css)$ {
	        add_header Pragma public;
		add_header Cache-Control "public, must-revalidate, proxy-revalidate";
		access_log off;
		expires 30d;
		break;
        }
}

server {
	listen $admin_port;
	
 	access_log off;
	log_not_found off;
 	error_log /home/$server_name/logs/nginx_error.log;
	
    	root /home/$server_name/private_html;
	index index.php index.html index.htm;
    	server_name $server_name;
 
	auth_basic "Restricted";
	auth_basic_user_file /home/$server_name/private_html/hocvps/.htpasswd;
	
	location / {
		autoindex on;
		try_files \$uri \$uri/ /index.php;
	}
	
    	location ~ \.php$ {
		fastcgi_split_path_info ^(.+\.php)(/.+)$;
        	include /etc/nginx/fastcgi_params;
        	fastcgi_pass 127.0.0.1:9000;
        	fastcgi_index index.php;
		fastcgi_connect_timeout 1000;
		fastcgi_send_timeout 1000;
		fastcgi_read_timeout 1000;
		fastcgi_buffer_size 256k;
		fastcgi_buffers 4 256k;
		fastcgi_busy_buffers_size 256k;
		fastcgi_temp_file_write_size 256k;
		fastcgi_intercept_errors on;
        	fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    	}
	
	location ~ /\. {
		deny all;
	}
}
END

cat >> "/etc/security/limits.conf" <<END
* soft nofile 262144
* hard nofile 262144
nginx soft nofile 262144
nginx hard nofile 262144
nobody soft nofile 262144
nobody hard nofile 262144
root soft nofile 262144
root hard nofile 262144
END

ulimit -n 262144

service nginx restart

# install mysql server
sudo yum -y install mysql-server
sudo /sbin/chkconfig --levels 235 mysqld on
sudo service mysqld start

# Open port
if [ -f /etc/sysconfig/iptables ]; then
service iptables start
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 25 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 465 -j ACCEPT
iptables -I INPUT -p tcp --dport 587 -j ACCEPT
iptables -I INPUT -p tcp --dport $admin_port -j ACCEPT
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
service iptables save
fi
mkdir -p /var/lib/php/session
chown -R nginx:nginx /var/lib/php
chown nginx:nginx /home/$server_name
chown -R nginx:nginx /home/*/public_html
chown -R nginx:nginx /home/*/private_html

clear
printf "=========================================================================\n"
printf "chuan bi cai dat htop \n"
printf "=========================================================================\n"
sleep 3

# innstal htop 
yum -y install htop

clear
printf "=========================================================================\n"
printf "chuan bi cai dat redis \n"
printf "=========================================================================\n"
sleep 3

# install redis

yum -y install epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
yum -y --enablerepo=remi,remi-php70 install redis php-pecl-redis
service php-fpm restart
chkconfig redis on
service redis start

# install git
yum -y install git

# install swap
sudo dd if=/dev/zero of=/swapfile bs=1024 count=1024k
mkswap /swapfile
swapon /swapfile
echo /swapfile none swap defaults 0 0 >> /etc/fstab
chown root:root /swapfile 
chmod 0600 /swapfile

# install java 8
# cd /opt/
# wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u151-b12/e758a0de34e24606bca991d704f6dcbf/jdk-8u151-linux-x64.tar.gz"
# tar xzf jdk-8u151-linux-x64.tar.gz



# Install Java 8 with Alternatives
# cd /opt/jdk1.8.0_151/
# alternatives --install /usr/bin/java java /opt/jdk1.8.0_151/bin/java 2
# alternatives --config java

# alternatives --install /usr/bin/jar jar /opt/jdk1.8.0_151/bin/jar 2
# alternatives --install /usr/bin/javac javac /opt/jdk1.8.0_151/bin/javac 2
# alternatives --set jar /opt/jdk1.8.0_151/bin/jar
# alternatives --set javac /opt/jdk1.8.0_151/bin/javac

# export JAVA_HOME=/opt/jdk1.8.0_151
# export JRE_HOME=/opt/jdk1.8.0_151/jre
# export PATH=$PATH:/opt/jdk1.8.0_151/bin:/opt/jdk1.8.0_151/jre/bin

# cd ~
# wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
# "http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jre-8u60-linux-x64.rpm"

# sudo yum localinstall jre-8u60-linux-x64.rpm
# rm ~/jre-8u60-linux-x64.rpm

# cd ~
# wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jdk-8u60-linux-x64.rpm"
# sudo yum localinstall jdk-8u60-linux-x64.rpm
# rm ~/jdk-8u60-linux-x64.rpm

yum -y remove java-1.6.0-openjdk
yum -y remove java-1.7.0-openjdk

yum -y install java-1.8.0-openjdk


# install maven

cd /usr/local
wget http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz
tar xzf apache-maven-3.5.2-bin.tar.gz
ln -s apache-maven-3.5.2  maven
touch /etc/profile.d/maven.sh
cat /etc/profile.d/maven.sh <<EOF
export M2_HOME=/usr/local/maven
export PATH=${M2_HOME}/bin:${PATH}
EOF

source /etc/profile.d/maven.sh
rm -f /usr/local/apache-maven-3.5.2-bin.tar.gz

# sudo wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
# sudo sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
# sudo yum install -y apache-maven
# mvn --version

printf "=========================================================================\n"
printf "cai dat hoan tat \n"
printf "hen gap lai\n"
printf "=========================================================================\n"
