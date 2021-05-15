#!/bin/bash
<<!
 **********************************************************
 * Author        : lihaimao
 * Email         : haimao_li@163.com
 * Last modified : 2021-04-16 09:06
 * Filename      : init_centos7
 * Description   :
 * *******************************************************
!

. /etc/rc.d/init.d/functions

if [ "$UID" -ne 0 ]
then
    echo "this script must be run by an administrator."
    exit 1
fi

# Variable definitions.
DATE=$(date +%F)
SELINUX_STATUS=$(getenforce)
SELINUX_FILE="/etc/selinux/config"
ISSUE="/etc/issue"
ISSUE_NET="/etc/issue.net"
PWQUALITY_FILE="/etc/security/pwquality.conf"
SYSTEM_AUTH="/etc/pam.d/system-auth-ac"
PAMD_SSHD="/etc/pam.d/sshd"
BASHRC="/etc/bashrc"
SSHD_FILE="/etc/ssh/sshd_config"
RSYSLOG_FILE="/etc/rsyslog.conf"
LISTEN_CONF="/etc/rsyslog.d/listen.conf"
BOOT_LOG="/var/log/boot.log"
LOGIN_DEFS="/etc/login.defs"
SU="/etc/pam.d/su"
PROFILE="/etc/profile"
BASE_REPO="/etc/yum.repos.d/CentOS-Base.repo"
EPEL_REPO="/etc/yum.repos.d/epel.repo"
NTP_CONF="/etc/ntp.conf"


# Disable postfix service.
function disable_postfix() {
    systemctl status postfix &>/dev/null
    RETVAL=$?
    if [ "$RETVAL" -eq 0 ]
    then
        systemctl stop postfix
        systemctl disable postfix &>/dev/null
    else
        echo "postfix service is not running."
    fi
}

# Hide system version information.
function hide_version() {
    [ -f "$ISSUE" ] && > $ISSUE
    [ -f "$ISSUE_NET" ]  && > $ISSUE_NET
}

# Set system alias.
function system_alias() {
    echo "alias ll='ls -l --color=auto --time-style=long-iso'" >> $BASHRC
    echo "alias vi='vim'" >> $BASHRC
    source $BASHRC
}

# Optimize sshd service.
function optimize_sshd() {
    [ -f "$SSHD_FILE" ] && cp -a $SSHD_FILE ${SSHD_FILE}_$DATE
    sed -i 's@^#Port 22@Port 22@g' $SSHD_FILE
    sed -i '/Port 22/a\Protocol 2' $SSHD_FILE
    sed -i 's@^#UseDNS yes@UseDNS no@g' $SSHD_FILE
#    sed -i 's@^#PermitRootLogin yes@PermitRootLogin no@g' $SSHD_FILE
    sed -i 's@^GSSAPIAuthentication yes@GSSAPIAuthentication no@g' $SSHD_FILE
#    sed -i 's@^#ClientAliveInterval 0@ClientAliveInterval 600@g' $SSHD_FILE
#    sed -i 's@^#ClientAliveCountMax 3@ClientAliveCountMax 2@g' $SSHD_FILE
    systemctl restart sshd
    systemctl enable sshd &>/dev/null
}

# Optimize rsyslog service.
function optimize_rsyslog() {
    [ -f "$RSYSLOG_FILE" ] && cp -a $RSYSLOG_FILE ${RSYSLOG_FILE}_$DATE
    echo "*.err;kern.debug;daemon.notice                          /var/log/messages" >> $RSYSLOG_FILE
    echo "*.* @10.205.42.13:514" >> $RSYSLOG_FILE
    chmod 640 $LISTEN_CONF
    chmod 640 $BOOT_LOG
    chmod 400 $RSYSLOG_FILE
    systemctl restart rsyslog
    systemctl enable rsyslog &>/dev/null
}

# Set the number of user history command records.
function history_command() {
    [ -f "$PROFILE" ] && cp -a $PROFILE ${PROFILE}_$DATE
    sed -i 's@^HISTSIZE=1000@HISTSIZE=4096@g' $PROFILE
    sed -i '/^HISTSIZE/a\HISTFILESIZE=4096' $PROFILE
    cat >> $PROFILE <<"EOF"
USER_IP=`who -u am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`
if [ -z $USER_IP ]
then
USER_IP=`hostname`
fi
HISTTIMEFORMAT="[%F %T] [`whoami`: $USER_IP] " 
export HISTTIMEFORMAT
EOF
    source $PROFILE
}

# Lock user.
function lock_user() {
    for user in adm lp mail operator games ftp nobody dbus sshd
    do
      usermod -L $user &>/dev/null
    done
}

# Determine whether the network is normal.
function network_status() {
    CODE=$(curl -I -s --connect-timeout 15 -w "%{http_code}\n" www.baidu.com -o /dev/null)
    if [ "$CODE" = "200" ]
    then
        echo "check the network is normal."
    else
        echo "check the network is not normal."
        exit 2
    fi
}

# Set the network yum repository.
function yum_repository() {
    network_status;
    curl -s -o $BASE_REPO http://mirrors.aliyun.com/repo/Centos-7.repo
    curl -s -o $EPEL_REPO http://mirrors.aliyun.com/repo/epel-7.repo
}

# Install the necessary software.
function install_software() {
    yum -y install lrzsz vim dos2unix wget ntpdate iftop epel-release ntp net-tools telnet tree sysstat unzip &>/dev/null
    yum -y install dsniff lvm2 lsof &>/dev/null
}

# Synchronization time server.
function synchronised_time() {
    /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    ntpdate time1.cloud.tencent.com &>/dev/null && hwclock &>/dev/null
    sed -i 'N;24aserver time1.cloud.tencent.com iburst' $NTP_CONF
    sed -i 'N;24aserver time2.cloud.tencent.com iburst' $NTP_CONF
    systemctl restart ntpd
    systemctl enable ntpd &>/dev/null
}

# optimize_kernel
function optimize_kernel() {
    cat >> /etc/sysctl.conf << EOF
vm.swappiness = 0
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
net.ipv4.tcp_max_syn_backlog = 819200
net.core.netdev_max_backlog = 400000
net.core.somaxconn = 4096
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_tw_recycle=0
EOF
    /sbin/sysctl -p
cat >> vim /etc/security/limits.conf << EOF
ulimit -HSn 400000
EOF
ulimit -HSn 400000
}

function init_vim() {
    cat >> /etc/vimrc << EOF

set nocompatible
set number
filetype on
set history=1000
syntax on
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set showmatch
EOF
}

# Main function.
function main() {
#    disable_selinux;
#    disable_firewalld;
    disable_postfix;
    hide_version;
#    password_policy;
    system_alias;
    optimize_sshd;
    optimize_rsyslog;
#    optimize_user;
    history_command;
    lock_user;
#    create_user;
    yum_repository;
    install_software;
    synchronised_time;
    optimize_kernel;
    init_vim;
}

# Run the main function.
main




