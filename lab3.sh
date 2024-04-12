#!/bin/bash
# This script runs the configure-host.sh script from the current directory to modify 2 servers and update the local /etc/hosts file


scp configure-host.sh remoteadmin@server1-mgmt:/root
ssh remoteadmin@server1-mgmt -- /root/configure-host.sh -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
scp configure-host.sh remoteadmin@server2-mgmt:/root
ssh remoteadmin@server2-mgmt -- /root/configure-host.sh -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3
./configure-host.sh -hostentry loghost 192.168.16.3
./configure-host.sh -hostentry webhost 192.168.16.4

# This section of code is ensuring script runs in verbose
	verbose=true 

# This section of code is creating a log file for error, warning, progress messages/logs
	# Specify log file
	log_file="logfile.txt"
	
	# Function to log the messages with date and time and append to log_file
	log_message() {
    		local message="$1"
    		echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
	}

	# Call the function
		log_message 

# This section of code will check if script exists and is copied and working properly
# This command will send all output to logfile
	exec >> logfile.txt 2>&1
# Set function to check if each command works
	run_command() {
    	    local command="$1"
    	    local description="$2"

    	    if [ "$verbose" = true ]; then
                echo "Executing: $description"
                if ! "$command"; then
                    echo "Error: $description"
                    exit 1
                fi
                echo "Success: $description"
    	   else
        	if ! "$command"; then
            	    exit 1
                fi
    	   fi
	}
	
# Check if configure-host.sh script exists locally
	if [ ! -f "configure-host.sh" ]; then
	    echo "Error: configure-host.sh script could not be found."
	exit 1
	fi

# Check if configure-host.sh script exists remotely on server1-mgmt
	run_command "ssh remoteadmin@server1-mgmt '[ -f /root/configure-host.sh ]'" "Checking configure-host.sh on server1-mgmt"
	
# Check if configure-host.sh script exists remotely on server2-mgmt
	run_command "ssh remoteadmin@server2-mgmt '[ -f /root/configure-host.sh ]'" "Checking configure-host.sh on server2-mgmt"
	
# See if configure-host.sh will run on server1-mgmt
	run_command "scp configure-host.sh remoteadmin@server1-mgmt:/root" "Copying configure-host.sh to server1-mgmt"
	run_command "ssh remoteadmin@server1-mgmt -- /root/configure-host.sh -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4" "Running configure-host.sh on server1-mgmt"

# See if configure-host.sh will run on server2-mgmt
	run_command "scp configure-host.sh remoteadmin@server2-mgmt:/root" "Copying configure-host.sh to server2-mgmt"
	run_command "ssh remoteadmin@server2-mgmt -- /root/configure-host.sh -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3" "Running configure-host.sh on server2-mgmt"
	
# See if configure-host.sh will run locally
	./configure-host.sh -hostentry loghost 192.168.16.3

# See if configure-host.sh will run locally
	./configure-host.sh -hostentry webhost 192.168.16.4

# If any test failed, the script will exit with error code. If all tests worked successfully, send this message
	echo "All tests passed successfully."
