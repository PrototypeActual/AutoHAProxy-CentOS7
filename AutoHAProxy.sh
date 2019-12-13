#!/bin/bash
#CT aka PrototypeActual
#HAProxy 1.8.14
#December 10th 2019

#add mod_ssl to the install line if having problems with ssl; but also note it will install httpd with it.

#This section updates the machine and then grabs HAProxy installation files/dependencies
yum update -y

yum install wget gcc pcre-static pcre-devel openssl-devel -y

wget https://www.haproxy.org/download/1.8/src/haproxy-1.8.14.tar.gz -O ~/haproxy.tar.gz

tar xzvf ~/haproxy.tar.gz -C ~/

cd ~/haproxy-1.8.14

make TARGET=linux2628 USE_OPENSSL=yes

make install

cp /usr/local/sbin/haproxy /usr/sbin/

cp ~/haproxy-1.8.14/examples/haproxy.init /etc/init.d/haproxy

mkdir -p /etc/haproxy

mkdir -p /home/haproxy

mkdir -p /var/lib/haproxy

touch /var/lib/haproxy/stats

useradd -r haproxy

chown haproxy:haproxy /etc/init.d/haproxy

chown haproxy:haproxy /home/haproxy

sudo haproxy -v

setsebool -P haproxy_connect_any=1

firewall-cmd --permanent --add-service=http

firewall-cmd --permanent --add-service=https

firewall-cmd --reload

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/haproxy/ssl/HAProxy.localdomain.key -out /etc/haproxy/ssl/HAProxy.localdomain.crt

cat > /etc/haproxy/ssl/haproxy.localdomain.key /etc/haproxy/ssl/haproxy.localdomain.crt > /etc/haproxy/ssl/haproxy.localdomain.pem

cat > /etc/haproxy/haproxy.cfg <<EOF
global
 log /dev/log local0
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

frontend seeddms.local
    bind *:80
    bind *:443 ssl crt /etc/haproxy/ssl/haproxy.localdomain.pem
    default_backend web_servers
    stats uri /haproxy?stats
    server 127.0.0.1:4331 check

backend web_servers
    option httpchk
    option forwardfor
    balance source
    redirect scheme https if !{ ssl_fc }
    cookie PHPSESSID insert nocache secure maxidle 900s maxlife 3600s
    server Apache1 ENTERIPOFHTTPDSERVER:80 check cookie s1
EOF

vi /etc/haproxy/haproxy.cfg

service haproxy start

systemctl enable haproxy

echo "Would you like to remove the haproxy install files gathered before?"
select yn in "Yes" "No"; do
  case $yn in
    Yes ) rm -rf /root/haproxy.tar.gz; rm -rf /root/haproxy-1.8.14; break;;
    No ) exit;;
  esac
done

echo "Haproxy will probably fail regarless how flawless this was done so reboot when you can unless the error is out of the ordinary."
