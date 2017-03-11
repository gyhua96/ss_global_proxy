#!/bin/bash
### BEGIN INIT INFO
# Provides:          shadowsocks
# Required-Start:    $local_fs $remote_fs $network $syslog $named
# Required-Stop:     $local_fs $remote_fs $network $syslog $named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: Apache2 web server
# Description:       Start the web server
#  This script will start the apache2 web server.
### END INIT INFO
SS_PID=$$
SS_PID_FILE=/tmp/shadowsocks.pid
CHAIN_NAME=SHADOWSOCKS
SS_IP=169.44.126.240
SS_PORT=51496
SS_LOCAL_PORT=1080
cleanup(){
	echo "clean config"
	sudo iptables -t nat -F $CHAIN_NAME
	sudo iptables -t nat -D OUTPUT -j $CHAIN_NAME
	sudo iptables -t nat -X $CHAIN_NAME

	# delete pid file
	sudo rm -rf $SS_PID_FILE
}

case "$1" in
	start)
		if [ -f "$SS_PID_FILE" ]; then
			echo "Error:"
			echo "    Already start Shadowsocks Global Agent."
			echo "(You can restart it by option restart)"
			exit 1
		fi

		log_progress_msg "start shadowsocks"
		echo $SS_PID > $SS_PID_FILE
		trap "cleanup" SIGINT
		trap "cleanup" SIGUSR1
		sudo iptables -t nat -N $CHAIN_NAME

		## iptables Ignore shadowsocks address
		sudo iptables -t nat -A $CHAIN_NAME -d $SS_IP -j RETURN
	
		## Ignore LANs and any other addresses you'd like to bypass the proxy
		sudo iptables -t nat -A $CHAIN_NAME -d 0.0.0.0/8 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 10.0.0.0/8 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 127.0.0.0/8 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 169.254.0.0/16 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 172.16.0.0/12 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 192.168.0.0/16 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 224.0.0.0/4 -j RETURN
		sudo iptables -t nat -A $CHAIN_NAME -d 240.0.0.0/4 -j RETURN
	
		## Anything else should be redirected to shadowsocks's local port
		sudo iptables -t nat -A $CHAIN_NAME -p tcp -j REDIRECT --to-ports $SS_LOCAL_PORT
		#sudo iptables -t nat -A $CHAIN_NAME -p udp -j REDIRECT --to-ports $SS_LOCAL_PORT
		#sudo iptables -t nat -A $CHAIN_NAME -p icmp -j REDIRECT --to-ports $SS_LOCAL_PORT
	
		# Apply the rules
		sudo iptables -t nat -L OUTPUT | grep $CHAIN_NAME >> /dev/null
		sudo iptables -t nat -I OUTPUT -j $CHAIN_NAME
		nohup sudo ss-redir -s $SS_IP -p $SS_PORT -l 1080 -k 19960514 -m aes-256-cfb > /dev/null 2>&1 & 
		exit 0
		;;
	stop)
		echo "stop shadowsocks"
		if [ ! -f "$SS_PID_FILE" ]; then
			echo "Shadowsocks Global Agent Never Starts."
			exit -1
		fi
		X_PID=$(cat $SS_PID_FILE)
		kill $X_PID > /dev/null 2>&1
		killall ss-redir > /dev/null 2>&1
		cleanup
		sleep 1
		#sudo rm -rf $SS_PID_FILE
		exit 0
		;;
	restart)
		echo "Please do stop then start!"
		exit 0
		;;
	*)
		echo "Unknow option"
		exit 1
		;;
esac
