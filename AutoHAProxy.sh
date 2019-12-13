#!/bin/bash
#CT aka PrototypeActual
#HAProxy 2.1.1
#December 10th 2019

echo "Here we go!"

wait 3

#This updates the machine and then grabs HAProxy installation files/dependencies
yum update -y

yum install wget gcc pcre-static pcre-devel openssl-devel systemd-devel -y

#This section makes a temporary folder in the current user home directory this script runs under and then downloads the HAProxy package

mkdir ~/temp

wget https://www.haproxy.org/download/2.1/src/haproxy-2.1.1.tar.gz -O ~/temp/haproxy-2.1.1.tar.gz

#This part extracts the HAProxy package to the previously mentioned temp folder and then switches to the unzipped directory to compile/install

tar xzvf ~/temp/haproxy-2.1.1.tar.gz -C ~/temp/

cd ~/temp/haproxy-2.1.1

make TARGET=linux-glibc USE_OPENSSL=yes USE_SYSTEMD=1

make install

#This section copies the files in /usr/local/sbin/haproxy to the /usr/sbin but trying an alterative and lastly copies over the systemd version of HAProxy to the /lib/systemd/system/

touch /etc/systemd/system/haproxy.service

cat > /etc/systemd/system/haproxy.service <<EOF
[Unit]
Description=HAProxy Load Balancer
After=network.target

[Service]
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid"
ExecStartPre=/usr/local/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q
ExecStart=/usr/local/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid
ExecReload=/usr/local/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q
ExecReload=/bin/kill -USR2 $MAINPID
KillMode=mixed
Restart=always
SuccessExitStatus=143
Type=notify

[Install]
WantedBy=multi-user.target
EOF

#This section makes new directories for HAProxy, creates the stats file for the HAProxy status page, and creates the haproxy user that the service will use to run.

mkdir -p /etc/haproxy

mkdir -p /home/haproxy

mkdir -p /var/lib/haproxy

touch /var/lib/haproxy/stats

useradd -r haproxy

chown haproxy:haproxy /home/haproxy

systemctl enable haproxy

haproxy -v

#This section allows HAProxy to bypass SELinux and allows traffic through Firewalld on http and https.

setsebool -P haproxy_connect_any=1

firewall-cmd --permanent --add-service=http

firewall-cmd --permanent --add-service=https

firewall-cmd --reload

#This seciton creates a certificate/key and then creates a pem file for the use of SSL traffic. Under the -subj you should tweak these to match your server/its location. 

openssl req -x509 \
 -nodes -days 365 -newkey rsa:2048 \
 -keyout /etc/ssl/haproxy.key \
 -out /etc/ssl/haproxy.crt \
 -subj "/C=US/ST=NY/L=Manhatten/CN=haproxy/emailAddress=anemailhere@test.com"

cat /etc/ssl/haproxy.crt /etc/ssl/haproxy.key > /etc/ssl/haproxy.pem

#This creates the HAProxy config file and then brings up the VIM editor so you can change the server ip, make tweaks, etc.
cat > /etc/haproxy/haproxy.cfg <<EOF
global
 log /dev/log local0 info
 log /dev/log local1 notice
 chroot /var/lib/haproxy
 stats socket /home/haproxy/admin.sock mode 660 level admin
 stats timeout 30s
 user haproxy
 group haproxy
 daemon
    maxconn 1024
    tune.ssl.default-dh-param 2048
    ssl-default-bind-options no-sslv3 no-tls-tickets
    ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM$

defaults
   log global
   mode http
   option httplog
   option dontlognull
   retries 3
   timeout connect 5000ms
   timeout client 50000ms
   timeout server 50000ms

frontend web_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/haproxy.pem
    default_backend web_servers
    stats uri /haproxy?stats
    stats auth admin:haproxy #user/password for stats page

backend web_servers
    option httpchk
    option forwardfor
    balance source
    redirect scheme https if !{ ssl_fc }
    cookie PHPSESSID insert nocache secure maxidle 900s maxlife 3600s
    server Apache1 ENTERIPOFHTTPDSERVER:80 check cookie s1
EOF

vi /etc/haproxy/haproxy.cfg

#Now we start haprroxy for the first time and remove the temp directory to clean up

systemctl start haproxy

rm -rf ~/temp

echo "-----------------------------------------"

echo "You can visit the HAProxy stats page by typing in the IP address of the machine you ran this script on and then adding /haproxy?stats at the end"
