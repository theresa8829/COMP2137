#!/bin/bash

# This script will configure some basic host settings
# Settings to configure will be given on the command line
# If settings are already in place, script will do nothing and make no output unless running in verbose mode
# Any settings not already in place will be configured and applied, no output unless errors or in verbose mode
# Script must ignore TERM, HUP, INT signals

# * * * * * * * * * * * * * * * * * * * * * *

# This section of code is creating a log file for error, warning, progress messages/logs
	# Specify log file
	log_file="scriptlogs.txt"
	
	# Function to log the messages with date and time and append to log_file
	log_message() {
    		local message="$1"
    		echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
	}

	# Call the function
		log_message 
	
# Set default values for command line arguments
	verbose=false
	name=""
	ip=""
	host_entry=""

# This section of code is ignoring TERM, HUP, and INT signals during script
	# Function to ignore signals
		ignore_signals() {
    		    trap '' TERM HUP INT
		}

	# Call the function
		ignore_signals

	# Check if the signal handling was successful
		if [ $? -eq 0 ]; then
    		    echo "Signal handling was successfully modified."
		else
    		    echo "Failed to modify signal handling."
		fi

# This function will display usage information
	display_usage() {
    		echo "Usage: $0 [-verbose] [-name <name>] [-ip <ip_address>] [-hostentry <host_entry>]"
    		echo "Options:"
    		echo "  -verbose            Enable verbose mode"
    		echo "  -name <name>        Specify the name"
    		echo "  -ip <ip_address>    Specify the IP address"
    		echo "  -hostentry <host_entry> Specify the host entry"
    		exit 1
	}

# This section of code allows choices on the command line
	while [ $# -gt 0 ]; do
    	 case "$1" in
           --help | -h ) 

# This section of code will parse the given command line options 
	while [[ "$#" -gt 0 ]]; do
    	    case $1 in
                -verbose)
                    verbose=true
                    ;;
                -name)
                    name="$2"
            	    shift
            	    ;;
        	-ip)
            	    ip="$2"
            	    shift
            	    ;;
        	-hostentry)
            	    host_entry="$2"
            	    shift
            	    ;;
        	*)
            	    echo "Unknown option: $1" >&2
            	    display_usage
            	    ;;
    	    esac
    	    shift
	done

# This section of code will check if the required arguments were given
	if [ -z "$name" ] || [ -z "$ip" ] || [ -z "$host_entry" ]; then
    	    echo "Error: Missing required arguments."
    	    display_usage
	fi

# This section of code will update hostname with given hostname if required
	local desired_name="$2"
	local current_hostname=$(hostname)
	local current_fqdn=$(hostname -f)

	if [ "$current_hostname" != "$desired_name" ]; then
        # Update /etc/hostname
            echo "$desired_name" | sudo tee /etc/hostname >/dev/null

        # Update /etc/hosts
            sudo sed -i "s/$current_hostname/$desired_name/g" /etc/hosts

        # Apply the new hostname to the running machine
            sudo hostname "$desired_name"

	# This section of code is appending messages to log file
            log_message "Hostname has been updated to $desired_name"
	else
            log_message "Hostname is already set to $desired_name"
	fi

# This section of code will update ip address with given ip if required
	local desired_ip="$2"
	local lan_interface="$3"
	local current_ip=$(ip -o -4 addr show dev "$lan_interface" | awk '{print $4}' | cut -d'/' -f1)

	if [ "$current_ip" != "$desired_ip" ]; then
        # Update /etc/hosts
            sudo sed -i "s/$current_ip/$desired_ip/g" /etc/hosts

        # Update netplan file
            sudo sed -i "s/$current_ip/$desired_ip/g" /etc/netplan/*.yaml

        # Apply the new IP address to the running machine
            sudo ip addr replace "$desired_ip"/24 dev "$lan_interface"

            log_message "IP address has been updated to $desired_ip"
	else
            log_message "IP address is already set to $desired_ip"
	fi

# This section of code will ensure that hostname and ip address are in /etc/hosts
	local desired_name="$2"
	local desired_ip="$3"
	local hosts_file="/etc/hosts"

	if grep -q "$desired_name" "$hosts_file" && grep -q "$desired_ip" "$hosts_file"; then
            log_message "Host entry already exists in /etc/hosts for $desired_name with IP address $desired_ip"
	else
        # Update /etc/hosts file
            echo "$desired_ip $desired_name" | sudo tee -a "$hosts_file" >/dev/null
            log_message "Added host entry in /etc/hosts for $desired_name with IP address $desired_ip"
	fi

# This section of code will provide output based on verbose
	if [ "$verbose" = true ]; then
            echo "Name: $name"
            echo "IP Address: $ip"
            echo "Host Entry: $host_entry"
	else
            echo "Information has been successfully processed."
	fi 
	
