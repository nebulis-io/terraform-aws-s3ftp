#!/bin/bash
set -e

# =========================

sudo yum -y update

sudo yum -y install \
jq \
automake \
openssl-devel \
git \
gcc \
libstdc++-devel \
gcc-c++ \
fuse \
fuse-devel \
curl-devel \
libdb \
libdb-utils \
libxml2-devel

# =========================

git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse/

./autogen.sh
./configure

make
sudo make install

# =========================

sudo yum -y install vsftpd

sudo mkdir -p /etc/vsftpd/vsftpd_user_conf

sudo mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
sudo mv /tmp/vsftpd.conf /etc/vsftpd/vsftpd.conf
sudo cp /etc/pam.d/vsftpd /etc/pam.d/vsftpd.default.bak

sudo tee /etc/pam.d/vsftpd > /dev/null <<EOT
auth required pam_userdb.so db=/etc/vsftpd/login
account required pam_userdb.so db=/etc/vsftpd/login
EOT

sudo chown root:root -R /etc/vsftpd

# =========================

sudo cp /tmp/generate_login.sh /usr/bin/generate_login.sh
sudo chmod +x /usr/bin/generate_login.sh

# =========================

sudo mkdir /home/ftp