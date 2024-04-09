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
	
	# Function to log the messages with date and time
	log_message() {
    		local message="$1"
    		echo "$(date +"%Y-%m-%d %H:%M:%S") - $message" >> "$log_file"
	}

# This section of code allows choices on the command line
	while [ $# -gt 0 ]; do
    	 case "$1" in
           --help | -h )

# This function will run the script in verbose mode
	function echoverbose {
    		[ "$verbose" = "yes" ] && echo "$@"
	}

# This section of code will collect hostname from command-line argument
	hostname_to_collect="$1"

	hostname = sys. argv[1] 




	
	
	
	
	
	
	
