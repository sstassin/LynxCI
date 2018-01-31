#!/bin/bash

# To learn about the cryptocurrency Lynx, visit https://getlynx.io
#
# This script will create a full Lynx node with the following characteristics:
#	- Wallet is disabled
#	- RPC connections restricted to the local IP address only
#	- This build now includes a light weight block crawler. In your browser, just visit the IP 
#	  address or fqdn value you entered when done (be sure to set up your DNS properly). 
#     ie. http://seed11.getlynx.io
#	- a lightweight micro-miner will run and submit hashes to a randomly selected pool
# 
# If you opted during setup for a more secure device by disabling SSH access, you must use a local
# keyboard, video and mouse (KVM).
#
# Pool mining is enabled with this script, by default. 'cpuminer' is used and self tuned. 
# Less then ~5 khash/s on a Linode 2048 is normal. Random pool selection will occur from a built-in
# list in the /etc/rc.local file. This is done for redundancy. Feel free to customize the list
# in the rc.local file.
#
# This build averages 65% cpu usage for mining so the device is not pushed to hard. This is done 
# by useing 'cpulimit'.

# - Remote RPC mining functions are restricted, but can be adjusted in /etc/rc.local.
# - Be patient, it will take about 15 hours for this script to complete. 
# - The wallet is configured to be disabled, so no funds are stored on this node.
# - Root login is denied. The user account configured below has sudo. 
#
# When this script is complete, you will have a fully functioning Lynx node that will confirm
# transactions on the Lynx network. The script processes include directly downloading the bulk of 
# the blockchain, unpacking it and forcing the node to reconfirm the chain faster. This script will 
# build itself over the span of 15 hours before it completes. I will reboot and start lynxd on 
# it's own. The server can be rebooted anytime after the first 15 hours and the Lynx daemon will 
# restart automatically. If mining functions are part of this script, they will automatically start
# after a reboot too. Run '$crontab -l' for the start schedule. Feel free to customize.
#
# Submit ideas to make this script better at https://github.com/doh9Xiet7weesh9va9th/LynxNodeBuilder
#
# Management advice: Deploy this script once and never log into the server. Your work is done. If
# you are worried about security, new updates and new versions, just build another server with the 
# latest version of thhis script. This script can run on a device with only 1GB of RAM (like a 
# Raspberry Pi 3). It will always build an up-to-date Lynx node. Look for upgrade notices on the 
# twitter feed (https://twitter.com/getlynxio) for notices to rebuild your server to the latest 
# stable version.

BLUE='\033[94m'
GREEN='\033[32;1m'
YELLOW='\033[33;1m'
RED='\033[91;1m'
RESET='\033[0m'

print_info () {

    printf "$BLUE$1$RESET\n"
    sleep 1

}

print_success () {

    printf "$GREEN$1$RESET\n"
    sleep 1

}

print_warning () {

    printf "$YELLOW$1$RESET\n"
    sleep 1

}

print_error () {

    printf "$RED$1$RESET\n"
    sleep 1

}

detect_os () {
#
# Detect whether a system is raspbian, debian or ubuntu function
#

#OS=`cat /etc/os-release | egrep '^ID=' | cut -d= -f2`

#case "$OS" in
#         ubuntu) is_debian=Y ;;
#         debian) is_debian=Y ;;
#         raspbian) is_debian=Y ;;
#         *) is_debian=N ;;
#esac

#
# Since Ubuntu 16.04 has an old 4.3.x version of bash the read command's -t in 
# the compile_query function will fail. Here we set the is_debian flag for it.
# 
#if [ "$OS" = "ubuntu" ]; then
#    is_debian=Y
#fi

	OS=`cat /etc/os-release | egrep '^ID=' | cut -d= -f2`
	print_success "The local OS is a flavor of '$OS'."

}

update_os () {

	print_success "The local OS, '$OS', will be updated."

	if [ "$OS" = "debian" ]; then
		apt-get -o Acquire::ForceIPv4=true update -y
		DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
		apt-get -o Acquire::ForceIPv4=true upgrade -y
	elif [ "$OS" = "ubuntu" ]; then
		apt-get -o Acquire::ForceIPv4=true update -y
		DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::options::="--force-confdef" -o DPkg::options::="--force-confold"  install grub-pc
		apt-get -o Acquire::ForceIPv4=true upgrade -y
	else
		# 'raspbian' would evaluate here.
		apt-get update -y
		apt-get upgrade -y
	fi

}

compile_query () {

	if [ "$OS" != "ubuntu" ]; then

		#
		# Set the query timeout value (in seconds)
		#
		time_out=30
		query1="Install the latest stable Lynx release? (faster build time) (Y/n):"
		query2="Do you want ssh access enabled (more secure)? (y/N):" 
		query3="Do you want to sync with the bootstrap file (less network intensive)? (Y/n):" 
		query4="Do you want the miners to run (supports the Lynx network)? (Y/n):"

		#
		# Get all the user inputs
		#
		read -t $time_out -p "$query1 " ans1
		read -t $time_out -p "$query2 " ans2
		read -t $time_out -p "$query3 " ans3
		read -t $time_out -p "$query4 " ans4

		#
		# Set the compile lynx flag 
		#
		if [[ -z "$ans1" ]]; then
			compile_lynx=N
		elif [[ "$ans1" == "n" ]]; then
			compile_lynx=Y
		else
			compile_lynx=N
		fi

		#
		# Set the ssh enabled flag
		#
		case "$ans2" in
		         y) enable_ssh=Y ;;
		         n) enable_ssh=N ;;
		         *) enable_ssh=N ;;
		esac

		#
		# Set the latest bootstrap flag
		#
		case "$ans3" in
		         y) latest_bs=Y ;;
		         n) latest_bs=N ;;
		         *) latest_bs=Y ;;
		esac

		#
		# Set the mining enabled flag
		#
		case "$ans4" in
		         y) enable_mining=Y ;;
		         n) enable_mining=N ;;
		         *) enable_mining=Y ;;
		esac

	else

		# Becuase 'ubuntu' doesn't play well with our query, we go with the defaults.
		compile_lynx=Y 
		enable_ssh=N
		latest_bs=Y
		enable_mining=Y

	fi

}

set_network () {

	ipaddr=$(ip route get 1 | awk '{print $NF;exit}')
	hhostname="lynx$(shuf -i 100000000-199999999 -n 1)"
	fqdn="$hhostname.getlynx.io"
	print_success "Setting the local fully qualified domain name to '$fqdn.'"

	echo $hhostname > /etc/hostname && hostname -F /etc/hostname
	print_success "Setting the local host name to '$hhostname.'"

	echo $ipaddr $fqdn $hhostname >> /etc/hosts
	print_success "The IP address of this machine is $ipaddr."

}

set_accounts () {

	sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
	print_success "Direct login via the root account has been disabled. You must log in as a user."

	ssuser="lynx"
	print_warning "The user account '$ssuser' was created."

	sspassword="lynx"
	print_warning "The default password is '$sspassword'. Be sure to change after this build is complete."

	adduser $ssuser --disabled-password --gecos "" && \
	echo "$ssuser:$sspassword" | chpasswd

	adduser $ssuser sudo
	print_success "The new user '$ssuser', has sudo access."

}

install_blockcrawler () {

	apt-get install nginx php7.0-fpm php-curl -y
	print_success "Installing Nginx..."

	mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

	echo "
	server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        index index.php;
        server_name _;
        location / {
			try_files \$uri \$uri/ =404;
        }

        location ~ \.php$ {
			include snippets/fastcgi-php.conf;
			fastcgi_pass unix:/run/php/php7.0-fpm.sock;
        }

	}
	" > /etc/nginx/sites-available/default
	print_success "Nginx is configured."

	# Created with "tar --exclude=.git* --exclude=.DS* -cvzf BlockCrawler.tar.gz BlockCrawler"
	cd /var/www/html/ && wget http://cdn.getlynx.io/BlockCrawler.tar.gz
	tar -xvf BlockCrawler.tar.gz
	cd BlockCrawler && mv * .. && cd .. && rm -R BlockCrawler

	sed -i -e 's/'"127.0.0.1"'/'"$ipaddr"'/g' /var/www/html/bc_daemon.php
	sed -i -e 's/'"8332"'/'"9332"'/g' /var/www/html/bc_daemon.php
	sed -i -e 's/'"username"'/'"$rrpcuser"'/g' /var/www/html/bc_daemon.php
	sed -i -e 's/'"password"'/'"$rrpcpassword"'/g' /var/www/html/bc_daemon.php
	print_success "Block Crawler code is secured for this Lynxd node."

	systemctl restart nginx && systemctl enable nginx && systemctl restart php7.0-fpm
	print_success "Nginx is set to auto start on boot."

	iptables -I INPUT 3 -p tcp --dport 80 -j ACCEPT
	print_success "The Block Crawler can be browsed at http://$ipaddr/"

}

install_extras () {

	apt-get install cpulimit htop curl fail2ban -y
	print_success "The package 'curl' was installed as a dependency of the 'cpuminer-multi' package."
	print_success "The package 'cpulimit' was installed to throttle the 'cpuminer-multi' package."

	apt-get install automake autoconf pkg-config libcurl4-openssl-dev libjansson-dev libssl-dev libgmp-dev make g++ -y
	print_success "Extra optional packages for CPUminer were installed."
} 

install_lynx () {

	apt-get install git-core build-essential autoconf libtool libssl-dev libboost-all-dev libminiupnpc-dev libevent-dev libncurses5-dev pkg-config -y

	rrpcuser="$(shuf -i 200000000-299999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcuser'."
	rrpcpassword="$(shuf -i 300000000-399999999 -n 1)"
	print_warning "The lynxd RPC user account is '$rrpcpassword'."

	if [ "$compile_lynx" = "Y" ]; then

		print_success "Pulling the latest source of Lynx from Github."
		git clone https://github.com/doh9Xiet7weesh9va9th/lynx.git /root/lynx/
		cd /root/lynx/ && ./autogen.sh
		./configure --disable-wallet
		print_success "The latest state of Lynx is being compiled now."
		make

	else

		print_success "The latest stable release of Lynx is being installed now."

		wget http://cdn.getlynx.io/lynxd-beta.deb
		dpkg -i lynxd-beta.deb 

	fi

	mkdir -p /root/.lynx && cd /root/.lynx
	print_success "Created the '.lynx' directory."

	if [[ "$latest_bs" == "Y" ]]; then
		wget http://cdn.getlynx.io/bootstrap.tar.gz
		tar -xvf bootstrap.tar.gz bootstrap.dat
		print_success "The bootstrap.dat file was downloaded and will be used after reboot."
	else
		print_error "The bootstrap.dat file was not downloaded."
	fi

	echo "
	listen=1
	daemon=1
	rpcuser=$rrpcuser
	rpcpassword=$rrpcpassword
	rpcport=9332
	port=22566
	rpcbind=$ipaddr
	rpcallowip=$ipaddr
	listenonion=0
	" > /root/.lynx/lynx.conf
	print_success "Default '/root/.lynx/lynx.conf' file was created."

	chown -R root:root /root/.lynx/*

} 

install_cpuminer () {

	git clone https://github.com/tpruvot/cpuminer-multi.git /root/cpuminer
	print_success "Mining package was downloaded."
	cd /root/cpuminer
	./autogen.sh
	./configure --disable-assembly CFLAGS="-Ofast -march=native" --with-crypto --with-curl
	make
	print_success "CPUminer Multi was compiled."

}

set_rclocal () {
#
# Initialize rclocal function
#
 
#
# Delete the rc.local file so we can recreate it with our firewall rules and follow-up scripts.

rm -R /etc/rc.local

#
#
# We will be recreating the rc.local file with a custom set of instructions below. This file is 
# only executed when the server reboots. It is (arguably) less tempermental then using a crontab
# and since this server probably won't be rebooted that often, it's a fine place to insert these 
# instructions. Also it's a very convenient script to run manually if needed, so rock on.

echo "
#!/bin/sh -e
#
#
# inits

#
#
# Becuase we are setting the values of 2 variables in this, rc.local file, we need to escape the
# expressions below where the variables are referenced. So we set the values here, and they can be
# changed in the future easily (followed by a reboot). But you will see the variables escaped
# in this script so they will work later when the rc.local file is created. It may look odd here
# but after this script runs, you will see a legit variable name below. Not to be confused with
# the variables name references we see for the variables at this top of this script. Those are
# used when the script is run for the very first time and are not subject to the particularities
# of the rc.local file. Instead of a reboot, you can always execute the rc.local as root and it
# will reset like a reboot. I prefer a reboot as a it shuts down orphaned processes that might 
# still be running.

IsSSH=$enable_ssh
IsMiner=$enable_mining


#
#
# If the 'lynxd' process is NOT running, then run the contents of this conditional. So the first
# time the script runs, like after a reboot the firewall will get set up. We are going to set up
# a crontab and run this file regularly.

if ! pgrep -x "lynxd" > /dev/null; then

	#
	#
	# The following iptables rules work well for running a tight server. Depending on the build
	# you executed with your Stackscript, your rules might be slightly different. The three basic
	# rules we care about are SSH (22), the Lynx Node RPC port used for mining (9332) and the
	# Lynx Nodenetwork port to listen from other Lynx nodes (22566).

	iptables -F
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

	#
	#
	# What fun would this be if someone didn't try to DDOS the block explorer? Lets assume they are 
	# gonna go at it old school and reuse the same addresses.

	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --set
	iptables -A INPUT -p tcp --dport 80 -m state --state NEW -m recent --update --seconds 60 --hitcount 15 -j DROP

	#
	#
	# If you opt to run this server without SSH (22) access, you won't be able to log in unless you
	# have a keyboard physically attached to the node. Or you can use Lish if you are using Linode,
	# which is basically the same thing.

	if [ \$IsSSH = true ]; then
		iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	fi

	#
	# We only need to open port 9332 if we intend to allow outside miners to send their work
	# to this node. By default, this is disbled, but you can enable it be uncommenting this line
	# and re-executing this file to load it. The Lynx node will start up listening to port 9332,
	# but you will have to add the IP address of the miner so it can connect.

	# iptables -A INPUT -p tcp --dport 9332 -j ACCEPT

	#
	#
	iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -A INPUT -p tcp --dport 22566 -j ACCEPT
	iptables -A INPUT -j DROP

	#
	#
	# Let's look for and clean up some left over build files that were used when this node was
	# first built. This will look after each reboot and silently remove these files if found.
	# Since this build is intended to be hands off, this script shouldn't be run very often. If
	# you want to update this node, it is best to just build a new server from this whole script
	# again.

	rm -Rf /root/.lynx/bootstrap.tar.gz
	rm -Rf /root/.lynx/bootstrap.dat.old
	rm -Rf /etc/update-motd.d/10-help-text

	#
	#
	# Start the Lynx Node. This is the bread and butter of the node. In all cases this should 
	# always be running. A crontab will also be run @hourly with the same command in case Lynx
	# ever quits. We found after extensive testing that this command would not fire correctly as
	# part of the /rc.local file after boot. So, instead a @hourly & @reboot crontab was
	# created with this instead.

	#
	# Removed this because the start process isn't working properly in the rc.local file. Instead
	# starting as a separate crontab.

	# cd /root/lynx/src/ && ./lynxd -daemon

#
#
# The end of the initial conditional interstitial

fi


#
#
# Of course after each reboot, we want the local miner to start, if it is set to turn on in
# this configuration. Notice we didn't open port 9332 on the firewall. This restricts outside
# miners from connecting to this node. This miner is only doing pool mining. It will get a few
# shares at the mining pool, but it will provide redundancy on the network in case big pools
# go down.

if [ \$IsMiner = true ]; then
	if pgrep -x "lynxd" > /dev/null; then
		if ! pgrep -x "cpuminer" > /dev/null; then

			minernmb="\$(shuf -i 1-2 -n1)"

			case "\$minernmb" in
				1) pool=" stratum+tcp://eu.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S" ;;
				2) pool=" stratum+tcp://us.multipool.us:3348 -u benjamin.seednode -p x -R 15 -B -S" ;;
				3) pool=" X" ;;
				4) pool=" XX" ;;
			esac

			/root/cpuminer/cpuminer -o$pool

		fi
	fi
fi

#
#
# During the initial built we installed cpulimit (http://cpulimit.sourceforge.net)
# It listens for the miner package when it runs and if detected, it will throttle 
# it to average about 80% of the processor instead of the full 100%. Linode and
# and some VPS vendors might have a problem with a node that is always using 100%
# of the processor so this is a simple tune-down of the local miner when it runs.
# If the minerd (https://github.com/pooler/cpuminer) process is not found, it will
# silently listen for it. It's fine to leave it running. Uses barely any resources.

if [ \$IsMiner = true ]; then
	if ! pgrep -x "cpulimit" > /dev/null; then
		cpulimit -e cpuminer -l 60 -b
	fi
fi

#
#
# You can always watch the debug log from your user account to check on the node's progress.

# $sudo tail -F /root/.lynx/debug.log

#
#
# You can also see who the firewall is blocking with fail2ban and see what ports are open

# $sudo iptables -L -vn

#
#
# The miner logs to the syslog, if it was installed in this built script.

# $sudo tail -F /var/log/syslog

#
#
# Its important this last line of the script remains here. Please dont touch it. 

exit 0

#
#trumpisamoron
#
" > /etc/rc.local

#
#
# Let's purge that first line in the rc.local file that was just created. For some reason, I
# couldn't avoid that first empty line above and I think it causes problems if I leave it there.
# No big deal. Let's just purge the first line only to keep it clean. #trumpisamoron

sed '1d' /etc/rc.local > tmpfile; mv tmpfile /etc/rc.local

#
#
# Let's not make any assumptions about the file permissions on teh rc.local file we just created. 
# We will force it to be 755.

chmod 755 /etc/rc.local

} # End set_rclocal function


secure_iptables () {

	iptables -F
	iptables -I INPUT 1 -i lo -j ACCEPT
	iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
	iptables -A INPUT -p tcp --dport 22 -j ACCEPT
	iptables -A INPUT -j DROP

}

config_fail2ban () {
	#
	# Configure fail2ban defaults function
	#

	#
	# The default ban time for abusers on port 22 (SSH) is 10 minutes. Lets make this a full 24 hours
	# that we will ban the IP address of the attacker. This is the tuning of the fail2ban jail that
	# was documented earlier in this file. The number 86400 is the number of seconds in a 24 hour term.
	# Set the bantime for lynxd on port 22566 banned regex matches to 24 hours as well. 

	echo "

	[sshd]
	enabled = true
	bantime = 86400


	[lynxd]
	enabled = true
	bantime = 86400

	" > /etc/fail2ban/jail.d/defaults-debian.conf

	#
	#
	# Configure the fail2ban jail for lynxd and set the frequency to 20 min and 3 polls 

	echo "

	#
	# SSH
	#

	[sshd]
	port		= ssh
	logpath 	= %(sshd_log)s

	#
	# LYNX
	#

	[lynxd]
	port		= 22566
	logpath		= /root/.lynx/debug.log
	findtime 	= 1200
	maxretry 	= 3

	" > /etc/fail2ban/jail.local

	#
	#
	# Define the regex pattern for lynxd failed connections

	echo " 

	#
	# Fail2Ban lynxd regex filter for at attempted exploit or inappropriate connection
	#
	# The regex matches banned and dropped connections  
	# Processes the following logfile /root/.lynx/debug.log
	# 

	[INCLUDES]

	# Read common prefixes. If any customizations available -- read them from
	# common.local
	before = common.conf

	[Definition]

	#_daemon = lynxd

	failregex = ^.* connection from <HOST>.*dropped \(banned\)$

	ignoreregex = 

	# Author: The Lynx Core Development Team

	" > /etc/fail2ban/filter.d/lynxd.conf

	#
	#
	# With the extra jails added for monitoring lynxd, we need to touch the debug.log file for fail2ban to start without error.

	touch /root/.lynx/debug.log

	#
	#
	# Let's use fail2ban to prune the probe attempts on port 22. If the jail catches someone, the IP
	# is locked out for 24 hours. We don't reallY want to lock them out for good. Also if SSH (22) is
	# not made public in the iptables rules, this package is not needed. It consumes so little cpu
	# time that I decide to leave it along. Fail2ban will always start itself so no need to add it to 
	# rc.local or a crontab. 

	service fail2ban start

}
 
set_crontab () {

	crontab -l | { cat; echo "*/5 * * * *		cd /root/lynx/src/ && ./lynxd -daemon"; } | crontab -
	print_success "A crontab for '/root/lynx/src/lynxd' has been set up. It will start automatically every 5 minutes."

	crontab -l | { cat; echo "*/15 * * * *		sh /etc/rc.local"; } | crontab -
	print_success "A crontab for the '/etc/rc.local' has been set up. It will execute every 15 minutes."

	crontab -l | { cat; echo "0 0 */15 * *		reboot"; } | crontab -
	print_success "A crontab for the server has been set up. It will reboot automatically every 15 days."

}

restart () {

	print_success "This Lynx node is built. A reboot and autostart will occur 10 seconds."
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1
	print_success "Please change the default password for the '$ssuser' user after reboot!"
	sleep 1

	reboot

}

detect_os
update_os
compile_query
set_network
set_accounts
install_extras
install_lynx
install_blockcrawler
install_cpuminer
set_rclocal
secure_iptables
config_fail2ban
set_crontab
restart
