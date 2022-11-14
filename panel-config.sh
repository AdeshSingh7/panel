#!/bin/bash
clear
mac_id()
	{
	cat  <<-EOF > /home/pi/parkplus-firmware/.env
	MAC_ADDRESS=$(ip link show eth0 | awk '/ether/ {print $2}')
	EOF
	}
panelip()
	{
	ip addr list eth0 |grep "inet " |cut -d' ' -f6|cut -d/ -f1
	}
active_tags()
	{
	sqlite3 --box /opt/sqlite/prod.db "select count(is_active) from tag_infra where is_active=1";
	}
tag_sync()
	{
	source <(printf "curl --location --request POST 'http://$(panelip):80/sync-infra' --data-raw ''")
	}
SD_Card_Config()
	{
	sudo rm -frv /opt/logs/* /opt/sqlite/* && cd /home/pi/parkplus-firmware/ && sudo docker-compose -f /home/pi/parkplus-firmware/docker-compose.yml up -d
	read -p "Press [Enter] key to continue..." readEnterKey
	}
i_build()
	{
	git -C /home/pi/parkplus-firmware/ pull && cd /home/pi/parkplus-firmware/ && sudo docker build -t parkplus-firmware /home/pi/parkplus-firmware/ && sleep 2
	}
main_menu()
	{
	exec bash panel-config
	}
# CONFIGURATION MENU #####################
configuration()
	{
		while [ 1 ]
		do
		CHOICE=$(
		whiptail --backtitle "RFID PANEL CONFIGURATION" --title ">>> CONFIGURATION - MENU <<<" --menu "Make your choice" 20 100 10 \
			"1)" "CONFIGURE SD CARD"   \
			"2)" "UPDATE CODE & IMAGE"  \
			"3)" "RE-CONFIGURE SD CARD [Remove existing LOGS & DB]" \
			"4)" "FIRMWARE CODE" \
			"5)" "FIRMWARE BRANCH" \
			"6)" "FIRMWARE STATUS" \
			"7)" "FIRMWARE IMAGES" \
			"8)" "REMOVE UNTAGGED FIRMWARE IMAGES [Free Space]" \
			"9)" "RESTART FIRMWARE" \
			"10)" "STOP FIRMWARE" \
			"11)" "back to main menu"  3>&2 2>&1 1>&3
		)
	#result=$(main_menu)
	case $CHOICE in
		"1)")   # Orange Pi
			res="$(hostname)"
			if [[ $res =~ "orangepipcplus" ]]; then
			whiptail --title "CONFIRMATION" --yesno "Do you want to proceed for configuration" 8 78 
				if [[ $? -eq 0 ]]; then
					FUNC=$(declare -f mac_id)
                    sudo -S <<< "4[f]CP@" bash -c "$FUNC; mac_id"
                    FUNC=$(declare -f SD_Card_Config)
                    sudo -S <<< "4[f]CP@" bash -c "$FUNC; SD_Card_Config" && whiptail --title "MESSAGE" --msgbox "Process completed successfully." 8 78  || whiptail --title "MESSAGE" --msgbox "Failed with exit status $?\n $SD " 8 78
                    read -p "Press [Enter] key to continue..." readEnterKey
				fi
			# Raspberry Pi
				elif [[ $res =~ "raspberrypi" ]]; then
					whiptail --title "CONFIRMATION" --yesno "Do you want to proceed for configuration" 8 78 
					if [[ $? -eq 0 ]]; then
					mac_id && SD_Card_Config && whiptail --title "MESSAGE" --msgbox "Process completed successfully." 8 78 || whiptail --title "MESSAGE" --msgbox "Failed with exit status $?\n $SD " 8 78
				elif [[ $? -eq 1 ]]; then
					whiptail --title "MESSAGE" --msgbox "Cancelling Process since user pressed [NO]." 8 78 
				elif [[ $? -eq 255 ]]; then
					whiptail --title "MESSAGE" --msgbox "User pressed ESC. Exiting the script" 8 78
				else
					result="This script doesn't support this system $res"
					fi
				fi
		;;
		"2)")
			res="$(hostname)"
			if [[ $res =~ "orangepipcplus" ]]; then
			FUNC=$(declare -f i_build)
			sudo -S <<< "4[f]CP@" bash -c "$FUNC; i_build" && sudo docker rm -f firmware redis && SD_Card_Config
			result="Code and firmware image updated successfully"
			elif [[ $res =~ "raspberrypi" ]]; then
			i_build && sudo docker rm -f firmware redis && mac_id && SD_Card_Config
			result="Code and firmware image updated successfully"
			else
					result="This script doesn't support this system $res"
			fi
		;;

		"3)")	#test on OPI
			res="$(hostname)"
			if [[ $res =~ "orangepipcplus" ]]; then
			FUNC=$(declare -f mac_id)
			sudo -S <<< "4[f]CP@" bash -c "$FUNC; mac_id" && sudo docker rm -f firmware redis && sudo rm -frv /opt/logs/* /opt/sqlite/* && cd /home/pi/parkplus-firmware/ && sudo docker-compose up -d && read -p "Press [Enter] key to continue..." readEnterKey
			elif [[ $res =~ "raspberrypi" ]]; then
			mac_id && sudo docker rm -f firmware redis && sudo rm -frv /opt/logs/* /opt/sqlite/* && cd ~/parkplus-firmware/ && sudo docker-compose up -d && read -p "Press [Enter] key to continue..." readEnterKey
			else
					result="This script doesn't support this system $res"
			fi
			p=$(sudo docker ps)
			result="FIRMWARE STATUS\n\n$p\n\n\nChanges done successfully"
		;;

		"4)")   
			op=$(git -C ~/parkplus-firmware/ log)
			result="$op"
		;;

		"5)")   
			op=$(git -C ~/parkplus-firmware/ branch | awk '{print $2}')
			result="Current Firmware Branch -->> $op"
		;;

		"6)")   
			op=$(sudo docker ps -a)
			result="= = = = = > FIRMWARE STATUS < = = = = =\n\n$op"
		;;
		"7)")   
			op=$(sudo docker images)
			result="= = = = = > FIRMWARE IMAGES < = = = = =\n\n$op"
		;;
		"8)")   
			op=$(sudo docker rmi $(sudo docker images -f "dangling=true" -q))
			result="= = = = = > DELETED FIRMWARE IMAGES < = = = = =\n\n$op"
		;;

		"9)")	OP=$(sudo docker restart firmware redis)
				result="$OP\n\nRESTART DONE..."
		;;
		"10)")	OP=$(sudo docker stop firmware)
				result="$OP\n\nFirmware Stopped..."
		;;
		"11)")	main_menu
		;;
	esac
	whiptail --backtitle "RESULTS" --msgbox --scrolltext "$result" 50 200
	done
	exit
	}

# Search tag #########################
search_tag()
	{
	while [ 1 ]
	do
	CHOICE=$(
	whiptail --backtitle "SEARCH TAG STATUS & ACTIVITY" --title " >>> SEARCH TAG STATUS & ACTIVITY - MENU <<< " --menu "Make your choice" 20 100 9 \
		"1)" "Status by TAG ID/FASTAG ID"   \
		"2)" "Status by Vehicle Number [VRN]"  \
		"3)" "Status by EPC CODE." \
		"4)" "TOTAL TAGS" \
		"5)" "Activity by TAG ID/FASTAG ID" \
		"6)" "Activity by Vehicle Number [VRN]" \
		"7)" "Activity by EPC CODE" \
		"8)" "Cloud Action by TAG/FASTAG ID" \
		"9)" "Cloud Action by Vehicle Number [VRN]" \
		"10)" "back to main menu"  3>&2 2>&1 1>&3
	)
	result=$(echo -e "= = = = = = >> SYSTEM DETAILS << = = = = = =\n\nUSER -->> $(whoami)\n\nHOSTNAME -->> $(hostname)\n\nIP ADDRESS -->> $(hostname -I)\n\nNAMESERVER -->> $(grep nameserver /etc/resolv.conf | awk '/nameserver/ {print $2}')\n\nMAC ADDRESS [LAN] -->> $(ip link show eth0 | awk '/ether/ {print $2}')\n\nMAC ADDRESS [.env] -->> $(cat /home/pi/parkplus-firmware/.env)\n\nDATE & TIME -->> $(date)")
	case $CHOICE in
		"1)")   
			tag_ids=$(whiptail --inputbox "Please Enter TAG ID" 16 100 --title "STATUS OF TAG ID" 3>&1 1>&2 2>&3)
			exitstatus=$?
			if [ $exitstatus = 0 ]; then
			OP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tag_infra where tag_id="$tag_ids"";)
			RP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tags where tag_id2="$tag_ids"";)
			SP=$(sqlite3 --line /opt/sqlite/prod.db "select * from vehicle where id in(select vehicle_id from tag_infra where tag_id="$tag_ids")";)
			result="= = = = = > DATA FROM TAG_INFRA < = = = = =\n$OP\n\n= = = = = > DATA FROM TAGS < = = = = =\n$RP\n\n= = = = = > DATA FROM VEHICLE < = = = = =\n$SP"
			else
				echo "User selected Cancel."
			fi
			echo "(Exit status was $exitstatus)"
		;;
		"2)")   
			VRN=$(whiptail --inputbox "Please Enter Vehicle Number [Use Capital letters only like HR87B1109]" 16 100 --title "STATUS OF TAG ID BY Vehicle Number" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tag_infra where vehicle_id in (select id from vehicle where license='${VRN^^}')";)
			RP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tags where tag_id2 in (select tag_id from tag_infra where vehicle_id in (select id from vehicle where license='${VRN^^}'));")
			SP=$(sqlite3 --line /opt/sqlite/prod.db "select * from vehicle where license='${VRN^^}'";)
			result="Vehicle Number = ${VRN^^}\n\n= = = = = > DATA FROM TAG_INFRA < = = = = =\n$OP\n\n= = = = = > DATA FROM TAGS < = = = = =\n$RP\n\n= = = = = > DATA FROM VEHICLE < = = = = =\n$SP\n"
		;;

		"3)")
			EPC=$(whiptail --inputbox "Please Enter EPC CODE" 16 100 --title "STATUS OF TAG ID BY EPC CODE" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --list /opt/sqlite/prod.db "select license from vehicle where id in (select vehicle_id from tag_infra where tag_id in (select tag_id2 from tags where epc_code='$EPC'))";)
			SP=$(sqlite3 --line /opt/sqlite/prod.db "select * from vehicle where license='$OP'";)
			RP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tag_infra where vehicle_id in (select id from vehicle where license='$OP')";)
			PP=$(sqlite3 --line /opt/sqlite/prod.db "select * from tags where tag_id2 in (select tag_id from tag_infra where vehicle_id in (select id from vehicle where license='$PP'));")
			result="EPC CODE = $EPC\nVEHICLE NUMBER = $OP\n\n= = = = = > DATA FROM VEHICLE < = = = = =\n$SP\n\n= = = = = > DATA FROM TAG_INFRA < = = = = =\n$RP\n\n= = = = = > DATA FROM TAGS < = = = = =\n$PP"
		;;

		"4)")   
			OP=$(sqlite3 /opt/sqlite/prod.db "select count(*) from tag_infra where is_active=1";)
			PP=$(sqlite3 /opt/sqlite/prod.db "select count(*) from tag_infra where is_active=0";)
			QQ=$(sqlite3 /opt/sqlite/prod.db "select count(*) from tag_infra";)
			result="Total active tags -->> $OP\n\nTotal inactve tags -->> $PP\n\nTotal Tags -->> $QQ"
		;;

		"5)")   
			tag_ids=$(whiptail --inputbox "Please Enter TAG ID" 16 100 --title "ACTIVITY STATUS OF TAG ID BY TAG ID" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "SELECT * from activity where tag_id='$tag_ids' order by id desc limit 10";)
			result="$OP"
		;;
		"6)")   
			VRN=$(whiptail --inputbox "Please Enter VEHICLE NUMBER " 16 100 --title "ACTIVITY STATUS OF TAG ID BY VEHICLE NUMBER" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "SELECT * from activity where vehicle_number='${VRN^^}' order by id desc limit 10";)
			result="$OP"
		;;
		"7)")   
			EPC=$(whiptail --inputbox "Please Enter TAG ID" 16 100 --title "ACTIVITY STATUS OF TAG ID BY EPC CODE" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "SELECT * from activity where epc_code='$EPC' order by id desc limit 10";)
			result="$OP"
		;;
		"8)")   
			tag_ids=$(whiptail --inputbox "Please Enter TAG ID" 16 100 --title "SEARCH CLOUD ACTION BY TAG ID" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "select * from cloud_action where json_extract(data,'$.tag_details.tag_id')='$tag_ids' order by id desc limit 10";)
			result="$OP"
		;;
		"9)")   
			VRN=$(whiptail --inputbox "Please Enter VEHICLE NUMBER" 16 100 --title "SEARCH CLOUD ACTION BY Vehicle Number [VRN]" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "select * from cloud_action where json_extract(data,'$.vehicle_details.license')='${VRN^^}' order by id desc limit 10";)
			result="$OP"
		;;
		"10)")	main_menu
			;;
	esac
	whiptail --backtitle "SEARCH RESULTS" --msgbox --scrolltext "$result" 40 125
	done
	exit
	}
## MONOTOR LOGS ######################
monitor_logs()
	{
	while [ 1 ]
	do
	CHOICE=$(
	whiptail --backtitle "Monitor RFID Firmware logs" --title " >>> MONITOR LOGS - MENU <<< " --menu "Make your choice" 20 100 8 \
		"1)" "Primary logs"   \
		"2)" "Request Response logs"  \
		"3)" "MQTT logs" \
		"4)" "Reader Logs" \
		"5)" "Presense loop Pinlevel [Primary Logs]" \
		"6)" "Grep Error [Primary Logs]" \
		"7)" "Grep TAG_ID, VRN, EPC [request response logs]" \
		"8)" "Search any text in all logs" \
		"9)" "back to main menu"  3>&2 2>&1 1>&3
	)
	result=$(echo -e "= = = = = = >> SYSTEM DETAILS << = = = = = =\n\nUSER -->> $(whoami)\n\nHOSTNAME -->> $(hostname)\n\nIP ADDRESS -->> $(hostname -I)\n\nNAMESERVER -->> $(grep nameserver /etc/resolv.conf | awk '/nameserver/ {print $2}')\n\nMAC ADDRESS [LAN] -->> $(ip link show eth0 | awk '/ether/ {print $2}')\n\nMAC ADDRESS [.env] -->> $(cat /home/pi/parkplus-firmware/.env)\n\nDATE & TIME -->> $(date)")
	case $CHOICE in
		"1)")   
			tail -f /opt/logs/primary*
			read -p "Press [Enter] key to continue..." readEnterKey
		;;
		"2)")   
			tail -f /opt/logs/request_resp*
			read -p "Press [Enter] key to continue..." readEnterKey
		;;

		"3)")   
			tail -f /opt/logs/mqtt*
			read -p "Press [Enter] key to continue..." readEnterKey
			;;

		"4)")   
			tail -f /opt/logs/reader*
			read -p "Press [Enter] key to continue..." readEnterKey
			;;

		"5)")   
			tail -f /opt/logs/primary* |grep "pinlevel"
			read -p "Press [Enter] key to continue..." readEnterKey
			;;
		"6)")   
			tail -f /opt/logs/primary* |grep "error"
			read -p "Press [Enter] key to continue..." readEnterKey
			;;
		"7)")
			grep_data=$(whiptail --inputbox "Please Enter TAG ID, VRN or EPC" 8 39 --title "Search TAG_ID, EPC and VRN" 3>&1 1>&2 2>&3)
			exitstatus=$?
			if [ $exitstatus = 0 ]; then
			OP=$(grep -a "$grep_data" /opt/logs/request_resp*)
			fi
			result="$OP"
			;;
		"8)")   
			text=$(whiptail --inputbox "Please Enter Your Text" 8 39 --title "Search any text in resquest response logs" 3>&1 1>&2 2>&3)
			OP=$(grep -a "$text" /opt/logs/*)
			result="$OP"
		;;
		"9)")	main_menu
			;;
	esac
	whiptail --msgbox --scrolltext "$result" 40 125
	done
	exit
	}
# MAIN MENU #######################
while [ 1 ]
do
	CHOICE=$(
	whiptail --backtitle "PARK+ RFID PANEL SCRIPT VERSION 1.0 [Kindly Report any Bug or Feedback to MANISH KUMAR]" --title "--- PARK+ PANEL CONFIGURATION MENU ---" --menu "Make your choice" 20 100 12 \
		"1)" "RFID FIRMWARE CONFIGURATION" \
		"2)" "SYNC ALL TAGS" \
		"3)" "SEARCH TAG ID/FASTAG/VEHICLE STATUS, CLOUD ACTION & ACTIVITY" \
		"4)" "SEARCH ACTIVITIY [NORMAL VIEW]" \
		"5)" "SEARCH ACTIVITIY [DETAIL VIEW]" \
		"6)" "SEARCH CLOUD ACTION" \
		"7)" "GATE & DEVICE INFO" \
		"8)" "MONITOR RFID SYSTEM LOGS" \
		"9)" "OPEN BOOM BARRIER [TEST]" \
		"10)" "BACKUP [LOGS & DB]" \
		"11)" "SHUT DOWN CONTROLLER [MAINTENANCE ACTIVITY]" \
		"12)" "ARMBIAN-CONFIG [TRANSFER IMAGE TO EMMC]" \
		"13)" "Exit"  3>&2 2>&1 1>&3
	)
	result=$(echo -e "= = = = = = >> SYSTEM DETAILS << = = = = = =\n\nUSER -->> $(whoami)\n\nHOSTNAME -->> $(hostname)\n\nIP ADDRESS -->> $(hostname -I)\n\nNAMESERVER -->> $(grep nameserver /etc/resolv.conf | awk '/nameserver/ {print $2}')\n\nMAC ADDRESS [LAN] -->> $(ip link show eth0 | awk '/ether/ {print $2}')\n\nMAC ADDRESS [.env] -->> $(cat /home/pi/parkplus-firmware/.env)\n\nDATE & TIME -->> $(date)")
	case $CHOICE in
		"1)")   
			configuration
		;;
		"2)")	
			AT=$( echo -e "Total active tags before sync"
				active_tags)
				echo -e "  Syncing tags please wait...\n"
			OP=$( tag_sync
				res=$?
				if test "$res" != "0"; then
				echo "tag sync fail with error code $res"
				else echo -e "\n\nTotal tags after sync"
					active_tags
				fi )
			result="$AT\n$OP"
		;;
		
		"3)")   search_tag
		;;

		"4)")   
			CA=$(whiptail --inputbox "Please Enter the Number of Search Results" 16 55 --title "SEARCH ACTIVITY [NORMAL INFO]" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --box /opt/sqlite/prod.db "SELECT id, vehicle_number, tag_id, epc_code, event_type, entry_gate, exit_gate, entry_time, exit_time, boom_status, sync_status from activity order by id desc limit $CA;";)
			result="$OP"
		;;
		"5)")   
			CA=$(whiptail --inputbox "Please Enter the Number of Search Results" 16 55 --title "SEARCH ACTIVITY [DETAIL INFO]" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "SELECT * from activity order by id desc limit $CA;";)
			result="$OP"
		;;
		"6)")   
			CA=$(whiptail --inputbox "Please Enter the Number of Search Results" 8 55 --title "SEARCH CLOUD ACTIONS" 3>&1 1>&2 2>&3)
			OP=$(sqlite3 --line /opt/sqlite/prod.db "SELECT * FROM cloud_action order by id desc limit $CA";)
			result="$OP"
		;;
		"7)")
			IP=$(sqlite3 --line /opt/sqlite/prod.db "select * from project";)
			OP=$(sqlite3 --box /opt/sqlite/prod.db "SELECT project_id, id, name, description, device_type, reader_type, ip_address, port FROM DEVICES;";)
			AP=$(sqlite3 --line /opt/sqlite/prod.db "select * from gates";)
			result="= = = = = > PROJECT DETAILS < = = = = =\n$IP\n\n= = = = = > DEVICE DETAILS < = = = = =\n$OP\n\n= = = = = > GATE DETAILS < = = = = =\n$AP\n"
		;;
		"8)") monitor_logs		
		;;
		"9)")   
			OP=$(curl --location --request POST 'http://$(panelip)/api/v4/gates/open/' --header 'Content-Type: application/json' --data-raw '{"action_type": "open_gate"}')
			result="OPEN GATE $OP"
		;;
		"10)")	{
				if [ -d "/home/pi/backup" ] 
				then
					echo "Backup folder exist. Moving files to backup"
					echo 5
					sudo cp -v /opt/sqlite/* /home/pi/backup/
					echo 10
					sudo cp -v /opt/logs/counter* /home/pi/backup/
					echo 20
					sudo cp -v /opt/logs/primary* /home/pi/backup/
					echo 30
					sudo cp -v /opt/logs/reader* /home/pi/backup/
					echo 50
					sudo cp -v /opt/logs/request_resp* /home/pi/backup/
					echo 70
					sudo cp -v /opt/logs/mqtt* /home/pi/backup/
					echo 80
					sudo cp -v /opt/logs/services* /home/pi/backup/
					echo 100
				else
					echo "Backup folder doesn't exist. Creating directory and moving backup files"
					sudo mkdir /home/pi/backup
					echo 5
					sudo cp -v /opt/sqlite/* /home/pi/backup/
					echo 10
					sudo cp -v /opt/logs/counter* /home/pi/backup/
					echo 20
					sudo cp -v /opt/logs/primary* /home/pi/backup/
					echo 30
					sudo cp -v /opt/logs/reader* /home/pi/backup/
					echo 50
					sudo cp -v /opt/logs/request_resp* /home/pi/backup/
					echo 70
					sudo cp -v /opt/logs/mqtt* /home/pi/backup/
					echo 80
					sudo cp -v /opt/logs/services* /home/pi/backup/
					echo 100
				fi
				} | whiptail --backtitle "Backup" --title "Creating Backup" --gauge "Please wait until process is complete..." 8 50 0
				result="BACKUP DONE..."
		;;
		"11)")	sudo shutdown now
		;;
		"12)")	sudo armbian-config
		;;
		"13)")	exit
		;;
	esac
    whiptail --msgbox --scrolltext "$result" $LINES $COLUMNS $(( LINES - 8))
done
exit
