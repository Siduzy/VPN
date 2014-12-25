#!/bin/bash

function checkPptpdOptions(){
    options=`grep ^[^#] /etc/ppp/options.pptpd`

    if [[ ! $options =~ ^name ]]; then echo "name pptpd" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*refuse-pap.* ]]; then echo "refuse-pap" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*refuse-chap.* ]]; then echo "refuse-chap" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*refuse-mschap.* ]]; then echo "refuse-mschap" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*require-mschap-v2.* ]]; then echo "require-mschap-v2" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*require-mppe.* ]]; then echo "require-mppe-128" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*ms-dns.* ]]; then echo "ms-dns 8.8.8.8" >> /etc/ppp/options.pptpd && echo "ms-dns 8.8.4.4" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*proxyarp.* ]]; then echo "proxyarp" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*lock.* ]]; then echo "lock" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*nobsdcomp.* ]]; then echo "nobsdcomp" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*novj.* ]]; then echo "novj" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*novjccomp.* ]]; then echo "novjccomp" >> /etc/ppp/options.pptpd; fi
    if [[ ! $options =~ .*nologfd.* ]]; then echo "nologfd" >> /etc/ppp/options.pptpd; fi

	echo options
}

function modifyIptables(){
        iptables -A INPUT -p gre -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 1723 -j ACCEPT
        iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -s 192.168.0.0/24 -o eth0 -j ACCEPT
        iptables -A FORWARD -d 192.168.0.0/24 -i eth0 -j ACCEPT
        iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o eth0 -j MASQUERADE

        ### Clear Old Rules
        iptables -F
        iptables -X
        iptables -Z
        iptables -t nat -F
        iptables -t nat -X
        iptables -t nat -Z
        ### * filter
        # Default DROP
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT DROP
        # INPUT Chain
        iptables -A INPUT -p gre -j ACCEPT
        iptables -A INPUT -i lo -p all -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 21 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp -m tcp --dport 1723 -j ACCEPT
        iptables -A INPUT -p icmp -m icmp --icmp-type any -j ACCEPT
        iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        # OUTPUT Chain
        iptables -A OUTPUT -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
        # FORWARD Chain
        iptables -A FORWARD -s 192.168.0.0/24 -o eth0 -j ACCEPT
        iptables -A FORWARD -d 192.168.0.0/24 -i eth0 -j ACCEPT
        ### * nat
        # POSTROUTING Chain
        iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o eth0 -j MASQUERADE
}


function checkDependency(){
	
	## Dependencies for libpcap
	# yum -y install gcc
	# yum -y install flex
	# yum -y install bison
	
	## Download libpcap
	# wget http://www.tcpdump.org/release/libpcap-1.6.2.tar.gz
	# tar zxf libpcap-1.6.2.tar.gz
	# cd libpcap-1.6.2
	# ./configure
	# make
	# make install
	# cd ..
	
	# echo "/usr/local/lib" >> /etc/ld.so.conf
	# ldconfig
	yum -y install wget
    # Remove the old pptpd and ppp
    yum remove -y pptpd ppp
    toUninstall=`rpm -qa | grep -i ppp`
    rpm -e $toUninstall
    toUninstall=`rpm -qa | grep -i pptpd`
    rpm -e $toUninstall
	
	yum -y install ppp
	
    rm -rf /etc/pptpd.conf
    rm -rf /etc/ppp
	
    # Download ppp and pptpd
    # wget http://poptop.sourceforge.net/yum/stable/packages/ppp-2.4.5-33.0.rhel6.i686.rpm
    wget http://poptop.sourceforge.net/yum/stable/packages/pptpd-1.4.0-1.el6.i686.rpm

    # Install ppp and pptpd
    # rpm -Uvh ppp-2.4.5-33.0.rhel6.i686.rpm
    rpm -ivh pptpd-1.4.0-1.el6.i686.rpm

    # Install iptables
    yum -y install iptables
}


function installVPN(){
        echo "Begin to install VPN(PPTPD) services";

		# Check dependencies
		checkDependency

		# Check pptpd options
        checkPptpdOptions

        # Check pptpd.conf
        sed -i 's/logwtmp/# logwtmp/g' /etc/pptpd.conf
        echo "localip 192.168.0.1" >> /etc/pptpd.conf
        echo "remoteip 192.168.0.207-217" >> /etc/pptpd.conf

        # Init the first User
        echo "test pptpd test *" >> /etc/ppp/chap-secrets

        sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

        modifyIptables
        iptables-save > iptables.backup
		
        modprobe bridge
        lsmod|grep bridge
        sysctl -p

        service pptpd start 
        service iptables save
		# chkconfig --level 35 pptpd on
		# chkconfig --level 35 pptpd on
	    echo "modprobe bridge" >> /etc/rc.local
	    echo "lsmod|grep bridge" >> /etc/rc.local
	    echo "sysctl -p" >> /etc/rc.local
	    echo "service pptpd start" >> /etc/rc.local
	    echo "service iptables start" >> /etc/rc.local
		
		echo "Install finished!"
}

function repaireVPN(){
        echo "begin to repaire VPN";
        modprobe bridge
        lsmod|grep bridge
        sysctl -p
		
		service pptpd start
        service iptables start
}

function addVPNuser(){
        echo "input user name:"
        read username
        echo "input password:"
        read userpassword
        echo "${username} pptpd ${userpassword} *" >> /etc/ppp/chap-secrets
        service iptables restart
        service pptpd start
}

echo "which do you want to?input the number."
echo "1. install VPN service"
echo "2. repaire VPN service"
echo "3. add VPN user"
read num

case "$num" in
[1] ) (installVPN);;
[2] ) (repaireVPN);;
[3] ) (addVPNuser);;
*) echo "nothing,exit";;
esac
