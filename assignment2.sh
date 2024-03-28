#!/bin/bash
# The purpose of this script is to print a summary of hosts and IP addresses when it runs.
# *** TODO: Make functions to call for different exit status, warnings, errors, changes made

# Variables for /etc/hosts file server1
server1address=192.168.16.21/24

# Maybe?? We will first check for sudo and have user input sudo now so don't have to do it later!
	## echo "Checking for sudo..."
	# *** TODO: Should have a way for user to enter sudo password

# 1. This section of code is to change netplan configuration
	# This section of code is to update /etc/hosts file
	echo "Adding server1 to /etc/hosts file if necessary..."
	sudo sed -i "$server1address server1" /etc/hosts 
	# *** TODO: Pretty up with output
	
	# Apply new configurations
	sudo netplan apply
	echo "Successfully added server1 to /etc/hosts file!"

# 2. This section of code is to install the following software
	# This command will install apache2 and default configs
	sudo apt update
	sudo apt install apache2
	service apache2 reload

	# This command will install squid web proxy and default configs
	sudo apt-get install squid
	sudo systemctl start squid
	sudo systemctl enable squid

# 3. This section of code is to ensure the required firewall is implemented and enabled using ufw
	# Installing ufw in case it is not already installed
	echo "Checking if ufw is installed. Will install if necessary.." verbose
	sudo apt-get install ufw -y
	# Enable ufw
	sudo ufw enable
	# Enable SSH on port 22 on mgmt network only
	sudo ufw allow 22 from 172.16.1.1
	# Enable HTTP on both interfaces
	sudo ufw allow http
	# Enable web proxy on both interfaces
	sudo ufw allow 3128
	# Reload ufw to ensure changes are applied
	sudo ufw reload
	# This command will verify status of ufw to make sure it is active without error
	sudo systemctl status ufw verbose

# 4. This section of code is to create the required user accounts with the required configurations
	# Creating user dennis with home directory, bash login shell, and sudo access
	# *** TODO: Need to make this user two sets of keys, with both public keys saved to it's own authorized_keys file
	# *** TODO: Need to add 
	useradd -m -s /bin/bash dennis
	usermod -aG sudo dennis

	# Creating rest of users with home directory, bash login shell
	# User accounts to create
	users=("dennis", "aubrey", "captain", "snibbles", "brownie", "scooter", "sandy", "perrier", "cindy", "tiger", "yoda")
	
	# Create each user with home directory and bash as default login shell
	for user in "${users[@]}"; do
		sudo useradd -m -s /bin/bash "$users"
	done

	# This section of code is to create ssh keys for all users
	# Generating rsa keys for each user
	for user in "${users[@]}"; do
		if "$users" &>/dev/null; then
			echo "Generating SSH keys for $users.."
			
			# Create user's SSH directory if it doesn't exist
			sudo -u "$users" mkdir -p /home/"$users"/.ssh
			sudo chmod 700 "/home/${users}/.ssh"
			
			# Generate RSA key pair
			if [ ! -f "/home/$users/.ssh/id_rsa" ]; then
				sudo -i -u "$users" ssh-keygen -t rsa -N "" -f "/home/$users/.ssh/id_rsa"
			fi
			
			# Generate ed25519 key pair
			if [ ! -f "/home/$users/.ssh/id_ed25519" ]; then
				sudo -i -u "$users" ssh-keygen -t ed25519 -N "" -f "/home/$users/.ssh/ed25519"
			fi
			
			# Appending public keys to authorized_keys file
			cat "/home/$users/.ssh/id_rsa.pub" | sudo -u "$users" tee -a "/home/$users/.ssh/authorized_keys" >/dev/null
			cat "/home/$users/.ssh/id_ed25519.pub" | sudo -u "$users" tee -a "/home/$users/.ssh/authorized_keys" >/dev/null
		else
			echo "User $users does not exist." 
		fi
	done

