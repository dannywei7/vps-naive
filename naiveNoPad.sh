#!/bin/bash

#fonts color
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

# command install
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi



function install_naive(){
CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
if [ "$CHECK" == "SELINUX=enforcing" ]; then
    red "======================================================================="
    red "检测到SELinux为开启状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
    red "======================================================================="
    read -p "是否现在重启 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
	    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	    echo -e "VPS 重启中..."
	    reboot
	fi
    exit
fi
if [ "$CHECK" == "SELINUX=permissive" ]; then
    red "======================================================================="
    red "检测到SELinux为宽容状态，为防止申请证书失败，请先重启VPS后，再执行本脚本"
    red "======================================================================="
    read -p "是否现在重启 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
	    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            setenforce 0
	    echo -e "VPS 重启中..."
	    reboot
	fi
    exit
fi
if [ "$release" == "centos" ]; then
    if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop firewalld
    systemctl disable firewalld
    rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
elif [ "$release" == "ubuntu" ]; then
    if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
    red "==============="
    red "当前系统不受支持"
    red "==============="
    exit
    fi
    systemctl stop ufw
    systemctl disable ufw
    apt-get update
fi
$systemPackage -y install libnss3 dnsutils xz-utils wget unzip zip curl tar >/dev/null 2>&1

green "======================="
yellow "请输入绑定到本VPS的域名"
green "======================="
read your_domain
real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
	green "=========================================="
	green "       域名解析正常，开始安装naive"
	green "=========================================="
	sleep 1s

## install caddy	
#curl -OJ 'https://caddyserver.com/download/linux/amd64?plugins=http.forwardproxy&license=personal'
#tar -xzf caddy_*.tar.gz
#setcap cap_net_bind_service=+ep caddy
####

## 解除caddy限制
ulimit -n 8192


## creat website
mkdir -p /var/www/html
wget https://github.com/arcdetri/sample-blog/archive/master.zip
unzip master.zip
cp -rf sample-blog-master/html/* /var/www/html/

## run caddy
green "======================="
yellow "请输入userid"
green "======================="
read your_userid
green "======================="
yellow "请输入pass"
green "======================="
read your_pass
yellow "请输入email"
green "======================="
read your_email


curl https://getcaddy.com | bash -s personal hook.service,http.forwardproxy



cat >  /usr/local/bin/Caddyfile <<-EOF
$your_domain
root /var/www/html
tls $your_email
forwardproxy {
  basicauth $your_userid $your_pass
  hide_ip
  hide_via
  probe_resistance secret.localhost
  upstream http://127.0.0.1:8080
}
EOF

caddy -service install -conf=/usr/local/bin/Caddyfile -agree=true

sudo setcap cap_net_bind_service=+ep /usr/local/bin/caddy

systemctl enable caddy
systemctl start caddy



wget https://github.com/dannywei7/vps-naive/raw/master/naiveproxy-v80.0.3987.87-3-linux-x64.tar.xz
tar -xf naiveproxy-v80.0.3987.87-3-linux-x64.tar.xz
mv naiveproxy-v80.0.3987.87-3-linux-x64 /usr/local/bin/naiveproxy

cat > /usr/local/bin/naiveproxy/config.json  <<-EOF
{
  "listen": "http://127.0.0.1:8080"
}
EOF

## start naive service
cat > ${systempwd}naive.service <<-EOF
[Unit]  
Description=naive  
After=network.target  
   
[Service]  
Type=simple  
ExecStart=/usr/local/bin/naiveproxy/naive "/usr/local/bin/naiveproxy/config.json"
ExecReload=  
ExecStop= 
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF

	chmod +x ${systempwd}naive.service
	systemctl enable naive.service
	systemctl start naive.service

wget https://github.com/dannywei7/vps-naive/raw/master/naiveproxy-v80.0.3987.87-3-win-x64.zip
unzip naiveproxy-v80.0.3987.87-3-win-x64.zip
mv -f naiveproxy-v80.0.3987.87-3-win-x64 /usr/local/bin/naiveClient


cat > /usr/local/bin/naiveClient/config.json  <<-EOF
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://$your_userid:$your_pass@$your_domain",
  "log": ""
}
EOF

cd /usr/local/bin/naiveClient
zip -q -r naive-cli.zip /usr/local/bin/naiveClient/
mkdir -p /var/www/html/client
mv -f /usr/local/bin/naiveClient/naive-cli.zip /var/www/html/client/

	green "======================================================================"
	green "Naiveproxy已安装完成，请使用以下链接下载Naive客户端，此客户端已配置好所有参数"
	green "1、复制下面的链接，在浏览器打开，下载客户端"
	yellow "http://${your_domain}/client/naive-cli.zip"	
	green "2、将下载的压缩包解压，打开文件夹，打开start.bat即打开并运行Naive客户端"
	green "3、打开stop.bat即关闭Naive客户端"
	green "======================================================================"



else
	red "================================"
	red "域名解析地址与本VPS IP地址不一致"
	red "本次安装失败，请确保域名解析正常"
	red "================================"


fi
}


# remove
function remove_naive(){
    red "================================"
    red "即将卸载naive"
    red "同时卸载安装的nginx"
    red "================================"
    systemctl stop naive
    systemctl disable naive
    rm -f ${systempwd}naive.service
    if [ "$release" == "centos" ]; then
        yum remove -y nginx
    else
        apt autoremove -y nginx
    fi
    rm -rf /usr/src/naive*
    rm -rf /usr/share/nginx/html/*
    green "=============="
    green "naive删除完毕"
    green "=============="
}

# bbr install
function bbr_boost_sh(){
    bash <(curl -L -s -k "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh")
}

# start_menu
start_menu(){
    clear
    green " ===================================="
    green " Naive 一键安装自动脚本      "
    green " 系统：centos7+/debian9+/ubuntu16.04+"
    green " ===================================="
    echo
    red " ===================================="
    yellow " 1. 一键安装 Naive"
    red " ===================================="
    yellow " 2. 安装 4 IN 1 BBRPLUS加速脚本"
    red " ===================================="
    yellow " 3. 一键卸载 Naive"
    red " ===================================="
    yellow " 0. 退出脚本"
    red " ===================================="
    echo
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_naive
    ;;
    2)
    bbr_boost_sh 
    ;;
    3)
    remove_naive
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "请输入正确数字"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu
