#!/bin/bash

usage() { 
	echo -e "\nUsage:$0 your.own.domain.com \n" 
} 

if [  $# -le 1 ] 
	then 
		usage
		exit 1
fi 

# set hostname
echo -e "setting hostname\n"
hostnamectl set-hostname $1

# install hyperd
echo -e "installing hyperd\n"
yum install -y gcc-c++ make
curl -sSl https://codius.s3.amazonaws.com/hyper-bootstrap.sh | bash

# install moneyd-xrp
echo -e "installing moneyd-xrp\n"
curl --silent --location https://rpm.nodesource.com/setup_10.x | bash -
yum install -y nodejs
yum install -y https://codius.s3.amazonaws.com/moneyd-xrp-4.0.0-1.x86_64.rpm
moneyd xrp:configure 
systemctl start moneyd-xrp

# install codiusd
echo -e "installing codiusd\n"
yum install -y git
npm install -g codiusd --unsafe-perm
cp codiusd.service.template /etc/systemd/system/codiusd.service
sed -i s/codius.example.com/`uname -n`/g /etc/systemd/system/codiusd.service
systemctl enable codiusd
systemctl start codiusd

# Request wildcard SSL cert from lets encrypt
echo -e "installing SSL certificate\n"
yum install -y git
git clone https://github.com/certbot/certbot
cd certbot
git checkout v0.23.0
./certbot-auto -n --os-packages-only
./tools/venv.sh
ln -s `pwd`/venv/bin/certbot /usr/local/bin/certbot
certbot -d `uname -n` -d *.`uname -n` --manual --preferred-challenges dns-01 --server https://acme-v02.api.letsencrypt.org/directory certonly

# install nginx
echo -e "installing nginx\n"
yum install -y epel-release
yum install -y nginx
systemctl enable nginx
echo 'return 301 https://$host$request_uri;' > /etc/nginx/default.d/ssl-redirect.conf
openssl dhparam -out /etc/nginx/dhparam.pem 2048
cp codius.conf.template /etc/nginx/conf.d/codius.conf
sed -i s/codius.example.com/`uname -n`/g /etc/nginx/conf.d/codius.conf
setsebool -P httpd_can_network_connect 1
systemctl start nginx

# open 443 on firewall
echo -e "opening 443 on firewall\n"
firewall-cmd --zone=public --add-port=443/tcp --permanent

echo -e "dunn duna dun\n"
