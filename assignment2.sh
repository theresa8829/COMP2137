#!/bin/bash
# The purpose of this script is to print a summary of hosts and IP addresses when it runs.

# 1. This section of code is to change netplan configuration
	# This section of code is to update /etc/hosts file
		server1_ip="192.168.16.21/24"
		server1_hostname="server1"

	# Add the new IP address and hostname to /etc/hosts if it doesn't already exist
		if grep -q "$server1_ip $server1_hostname" /etc/hosts; then
    	    	    echo "Entry for $server1_hostname with IP $server1_ip already exists in /etc/hosts."
		else
            	    echo "Adding entry for $server1_hostname with IP $server1_ip to /etc/hosts..."
            	    echo "$server1_ip $server1_hostname" | sudo tee -a /etc/hosts > /dev/null
            	    echo "Successfully added server1 to /etc/hosts file!"
		fi
	
	# Apply new configurations
		sudo netplan apply
		echo "New configurations have been applied and saved."



# 2. This section of code is to install the following software
	# This command will install apache2 and default configs
		if ! command -v apache2 &> /dev/null; then
    	    	    echo "Apache2 is not currently installed. Please wait while we install..."
    	    	    sudo apt update
    	    	    sudo apt install apache2 -y
    	    	    echo "Apache2 has successfully been installed."
		else
            	    echo "Apache2 is already installed on your machine."
		fi

	# This command will install squid web proxy and default configs
		if ! command -v squid &> /dev/null; then
    	    	    echo "Squid web proxy is not currently installed. Please wait while we install..."
    	    	    sudo apt update
    	    	    sudo apt install squid -y
    	    	    echo "Squid web proxy has successfully been installed."
		else
            	    echo "Squid web proxy is already installed on your machine."
		fi



# 3. This section of code is to ensure the required firewall is implemented and enabled using ufw
	# Checking if ufw is installed, and installing if not
		if ! command -v ufw &> /dev/null; then
    	    	    echo "ufw is not installed. Please wait while we install..."
    	    	    sudo apt update
    	    	    sudo apt install ufw -y
    	    	    echo "ufw has successfully been installed."
		else
    	    	    echo "ufw is already installed on your machine."
		fi
	
	# 3a. Enable SSH on port 22 on mgmt network only
		mgmt_network="172.16.1.1"
		if [ -f /etc/ssh/sshd_config ]; then
    	# Backup the original SSH configuration file
    	    	    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config_backup

    	# Update SSH configuration to listen only on port 22 for the specified network
    	    	    sudo "echo 'Port 22' > /etc/ssh/sshd_config"
    	    	    sudo "echo 'ListenAddress $mgmt_network' >> /etc/ssh/sshd_config"

    	# Restart SSH service to apply the changes
    	    	    sudo systemctl restart sshd
    	    	    echo "SSH has been configured to listen on port 22 only for network $mgmt_network."
		else
    	    	    echo "SSH configuration file /etc/ssh/sshd_config not found."
		fi
	
	# 3b. Enable HTTP on both interfaces
		server1_ip="192.168.16.21"
		mgmt_ip="172.16.1.1"

	# Check if Apache configuration file exists
		if [ -f /etc/apache2/sites-available/000-default.conf ]; then
    	# Backup the original Apache configuration file
    	    	    sudo cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf_backup

    	# Update Apache configuration to listen on the IP addresses of the two interfaces
    	    	    sudo sed -i "s/Listen 80/Listen $server1_ip:80\nListen $mgmt_ip:80/" /etc/apache2/sites-available/000-default.conf

    	# Restart Apache to apply configuration changes
    	    	    sudo systemctl restart apache2
    	    	    echo "HTTP port 80 has been enabled on interfaces $server1_ip and $mgmt_ip."
		else
    	    	    echo "Apache configuration file /etc/apache2/sites-available/000-default.conf not found."
		fi
	
	# 3c. Enable web proxy on both interfaces
		if [ -f /etc/squid/squid.conf ]; then
    	# Backup the original Squid configuration file
    	    	    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf_backup

    	# Update Squid configuration to listen on the IP addresses of the two interfaces
    	    	    sudo sed -i "s/http_access deny all/http_access allow all\nhttp_port $server1_ip:3128\nhttp_port $mgmt_ip:3128/" /etc/squid/squid.conf

    	# Restart Squid service to apply the changes
            	    sudo systemctl restart squid
    	    	    echo "Web proxy has been enabled on interfaces $server1_ip and $mgmt_ip."
		else
    	    	    echo "Squid configuration file /etc/squid/squid.conf not found."
		fi
	
	# Reload ufw to ensure changes are applied
		sudo ufw reload
		echo "Firewall configurations have been applied and saved."
	# This command will verify status of ufw to make sure it is active without error
		sudo systemctl status ufw verbose
	
	
	
# 4. This section of code is to create the required user accounts with the required configurations
	# * * * * * * USER DENNIS * * * * * * 
	# This section of code will create user dennis with home directory, bash login shell, and sudo access
		superuser="dennis"
	# Check if the user already exists
		if id "$superuser" &>/dev/null; then
    		    echo "User $superuser already exists."
		else
    		    echo "User $superuser does not exist. Please wait while we create user..."
    	# Create the user with home directory, bash as default shell, and grant sudo access
    		    sudo useradd -m -s /bin/bash -G sudo "$superuser"
    		    echo "User $superuser created with home directory, bash as default shell, and sudo access has been granted."
		fi

	# This section of code will first add given public key to authorized_keys file for user dennis
	# SSH access with given public key:
		given_pubkey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
	# Make ssh directory for user dennis
		sudo mkdir -p /home/dennis/.ssh
	# Set permissions to read, write, execute for .ssh directory
		sudo chmod 700 /home/dennis/.ssh
	# Copy the given public key to dennis authorized_keys file
		echo "$given_pubkey" >> /home/dennis/.ssh/authorized_keys
	# Set permissions to read, write for authorized_keys
		sudo chmod 600 /home/dennis/.ssh/authorized_keys
		echo "Public key has been saved in user dennis' authorized_keys file." 
		
	# This section of code will assign rsa and ed25519 keys and append both public keys to dennis' authorized_keys file
		# Generate RSA key pair
		if [ ! -f "/home/$superuser/.ssh/id_rsa.pub" ]; then
			sudo -i -u dennis ssh-keygen -t rsa -f "/home/$superuser/.ssh/id_rsa"
		fi 
		
		# Generate Ed25519 key pair
		if [ ! -f "/home/$superuser/.ssh/id_ed25519.pub" ]; then
			sudo -i -u dennis ssh-keygen -t ed25519 -f "/home/$superuser/.ssh/ed25519"
		fi 
		
		# Append public keys to authorized_keys file
		cat "/home/$superuser/.ssh/id_rsa" "/home/$superuser/.ssh/ed25519" >> "/home/"$superuser"/.ssh/authorized_keys" >/dev/null

	# * * * * * * REST OF USERS * * * * * * 
	# This section of code will create rest of users with home directory and bash shell as default
		users=("aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
	
	# Create each user with home directory and bash as default login shell
		for username in "${users[@]}"; do
    	# Check if the user already exists
    	    	    if id "$users" &>/dev/null; then
        		echo "User $users already exists."
    	            else
        # If not, create the user with home directory and bash as default login shell
        		sudo useradd -m -s /bin/bash "$users"
        		echo "User $users created with home directory and bash as default shell."
    	            fi
		done
		
	# This section of code will create ssh keys for each user, and append public keys to the corresponding authorized_keys file
		for username in "${users[@]}"; do
    	# First, check if the user exists
    		    if id "$users" &>/dev/null; then
        # Then, check if the user already has SSH keys
        		if [ ! -f "/home/$users/.ssh/id_rsa.pub" ] || [ ! -f "/home/$users/.ssh/id_ed25519.pub" ]; then
        # Generate rsa key pair
        		    sudo -i -u "$users" ssh-keygen -t rsa -f "/home/$users/.ssh/id_rsa"
        # Generate ed25519 key pair
            		    sudo -i -u "$users" ssh-keygen -t ed25519 -f "/home/$users/.ssh/id_ed25519"
        # Append public keys to corresponding authorized_keys file
            		    cat "/home/$users/.ssh/id_rsa.pub" "/home/$users/.ssh/id_ed25519.pub" | sudo -u "$users" tee -a "/home/$users/.ssh/authorized_keys" > /dev/null
        # Set permissions for .ssh directory and authorized_keys file
            		    sudo -u "$users" chmod 600 "/home/$users/.ssh/authorized_keys"
        		else
            		    echo "User $users already has SSH keys."
        		fi
    		    else
        		echo "User $users does not exist."
    		    fi
		done

