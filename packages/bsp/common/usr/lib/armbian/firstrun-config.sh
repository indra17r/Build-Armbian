#!/bin/bash

# TODO: convert this to use nmcli, improve network interfaces names handling (wl*, en*)
# or drop support for this and remove all related files

# Function calculates number of bit in a netmask
#
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
}

do_firstrun_automated_user_configuration()
{
	#-----------------------------------------------------------------------------
	#Notes:
	# - See /boot/armbian_first_run.txt for full list of available variables
	# - Variable names here must here must match ones in packages/bsp/armbian_first_run.txt.template

	#-----------------------------------------------------------------------------
	#Config FP
	local fp_config='/boot/armbian_first_run.txt'

	#-----------------------------------------------------------------------------
	#Grab user requested settings
	if [[ -f $fp_config ]]; then

		# Convert line endings to Unix from Dos
		sed -i $'s/\r$//' "$fp_config"

		# check syntax
		bash -n "$fp_config" || return

		# Load vars directly from file
		source "$fp_config"

		# Obtain backward configuration compatibility
		FR_net_static_dns=${FR_net_static_dns// /,}
		FR_net_static_mask=$(mask2cidr $FR_net_static_mask)

		#-----------------------------------------------------------------------------
		# - Remove configuration file
		if [[ $FR_general_delete_this_file_after_completion == 1 ]]; then
			dd if=/dev/urandom of="$fp_config" bs=16K count=1
			sync
			rm "$fp_config"
		else
			mv "$fp_config" "${fp_config}.old"
		fi

		#-----------------------------------------------------------------------------
		# Set Network
		if [[ $FR_net_change_defaults == 1 ]]; then
			# - Get 1st index of available wlan and eth adapters
			local fp_ifconfig_tmp='/tmp/.ifconfig'
			ifconfig -a | sed 's/[ \t].*//;/^\(lo\|\|bond0\|sit0\|ip6tnl0\)$/d' > "$fp_ifconfig_tmp" #export to file, should be quicker in loop than calling ifconfig each time.

			# find eth[0-9]
			for ((i=0; i<=9; i++))
			do
				if (( $(cat "$fp_ifconfig_tmp" | grep -ci -m1 "eth$i") )); then
					eth_index=eth${i}
					break
				fi
			done

			# Predictable Network Interface Names
			[[ -z $eth_index ]] && eth_index=$(cat "$fp_ifconfig_tmp" | grep -m1 "en" | cut -f1 -d":" | head -1)

			# find wlan[0-9]
			for ((i=0; i<=9; i++))
			do
				if (( $(cat "$fp_ifconfig_tmp" | grep -ci -m1 "wlan$i") )); then
					wlan_index=wlan${i}
					break
				fi
			done

			# Predictable Network Interface Names
			[[ -z $wlan_index ]] && wlan_index=$(cat "$fp_ifconfig_tmp" | grep -m1 "wl" | cut -f1 -d":" | head -1)

			rm "$fp_ifconfig_tmp"

			# for static IP we only append settings
			if [[ $FR_net_use_static == 1 ]]; then
				local FIXED_IP_SETTINGS="ipv4.method manual ipv4.address ${FR_net_static_ip}/${FR_net_static_mask} ipv4.dns ${FR_net_static_dns} ipv4.gateway ${FR_net_static_gateway}"
			fi

			if [[ -n $eth_index || -n $wlan_index ]]; then
				# delete all current connections
				LC_ALL=C nmcli -t -f UUID,DEVICE connection show | awk '{print $1}' | cut -f1 -d":" | xargs nmcli connection delete

				# - Wifi enable
				if [[ $FR_net_wifi_enabled == 1 ]]; then

					#Set wifi country code
					iw reg set "$FR_net_wifi_countrycode"

					nmcli con add con-name "Armbian wireless" type wifi ifname ${wlan_index} ssid "$FR_net_wifi_ssid" -- wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$FR_net_wifi_key" ${FIXED_IP_SETTINGS}
					nmcli con up "Armbian wireless"

					#Enable Wlan, disable Eth
					FR_net_ethernet_enabled=0

				# - Ethernet enable
				elif [[ $FR_net_ethernet_enabled == 1 ]]; then

					nmcli con add con-name "Armbian ethernet" type ethernet ifname ${eth_index} -- ${FIXED_IP_SETTINGS}
					nmcli con up "Armbian ethernet"

					#Enable Eth, disable Wlan
					FR_net_wifi_enabled=0

				fi
			fi
		fi
	fi
} #do_firstrun_automated_user_configuration

do_firstrun_automated_user_configuration

exit 0

