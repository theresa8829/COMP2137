#!/bin/bash
# This script creates a virtual network suitable for learning about networking
# created by dennis simpson 2023, all rights reserved

lannetnum="192.168.16"
mgmtnetnum="172.16.1"
vmintf=lxdbr0
vmintfip=$(ip r|awk /$vmintf/'{print $9}')
vmintfnetnum=$(sed s/\\.[[:alnum:]]$//<<<"$vmintfip")
prefix=server
startinghostnum=200
remoteadmin="remoteadmin"
numcontainers=1
puppetinstall=no
verbose=yes

source /etc/os-release

function echoverbose {
    [ "$verbose" = "yes" ] && echo "$@"
}

#define functions for help display and error messages
# This function will send an error message to stderr
# Usage:
#   error-message ["some text to print to stderr"]
#
function error-message {
  local prog
  prog="$(basename '$0')"
  echo "${prog}: ${1:-Unknown Error - a moose bit my sister once...}" >&2
}

# This function will send a message to stderr and exit with a failure status
# Usage:
#   error-exit ["some text to print" [exit-status]]
#
function error-exit {
  error-message "$1"
  exit "${2:-1}"
}

# allow choices on the command line
while [ $# -gt 0 ]; do
    case "$1" in
        --help | -h )
            echo "
Usage: $(basename "$0") [-h | --help] [--fresh] [--prefix targetnameprefix] [--user remoteadminaccountname] [--lannet A.B.C] [--mgmtnet A.B.C] [--count N] [--hostnumbase N] [--puppetinstall]
This script sets up a private network using containers in a Ubuntu hosting machine for educational purposes.
It has an OpenWRT router connecting the hosting OS lan to its wan interface, and 2 virtual networks called lan and mgmt on additional interfaces.
Will install and initialize lxd if necessary.
Will create lan and mgmt virtual networks if necessary using host 2 on each network for the router, both using /24 mask.
Will create openwrt router with lxdbr0 for WAN, lan for lan, and mgmt for private management network.
Creates target containers, named using target name prefix with the container number appended.
Creates a remote admin account with sudo privilege, no passwd access, and ssh access for the user who runs this script.
Adds host names with IP addresses to /etc/hosts inside the containers and in the hosting OS.
The hosting OS will have direct access to all the virtual networks using host number 1.
Can install Puppet tools.
Defaults
fresh:         false
prefix:        server
user:          remoteadmin
vmwarenet:     vmware dhcp assigned
lannet:        192.168.16
mgmtnet:       172.16.1
hostnumbase:   10
count:         1
puppetinstall: no
"
            exit
            ;;
        --puppetinstall )
            puppetinstall=yes
            ;;
        --fresh )
	    targets=$(lxc list|grep -o -w "$prefix".)
            echoverbose "Deleting any existing target containers"
            for target in $targets; do
                lxc delete "$target" --force
            done
            echoverbose "Deleting any existing openwrt container"
            #lxc delete openwrt --force
            lxc network delete lan
            lxc network delete mgmt
            ;;
        --prefix )
            if [ -z "$2" ]; then
                error-exit "Need a hostname prefix for the --prefix option"
            else
                prefix="$2"
                shift
            fi
            ;;
        --user )
            if [ -z "$2" ]; then
                error-exit "Need a username for the --user option"
            else
                remoteadmin="$2"
                shift
            fi
            ;;
        --lannet )
            if [ -z "$2" ]; then
                error-exit "Need a network number in the format N.N.N for the --lannet option"
            else
                vmintfnetnum="$2"
                shift
            fi
            ;;
        --mgmtnet )
            if [ -z "$2" ]; then
                error-exit "Need a network number in the format N.N.N for the --mgmtnet option"
            else
                mgmtnetnum="$2"
                shift
            fi
            ;;
        --count )
            if [ -z "$2" ]; then
                error-exit "Need a number for the --count option"
            else
                numcontainers="$2"
                shift
            fi
            ;;
        --hostnumbase )
            if [ -z "$2" ]; then
                error-exit "Need a number for the --hostnumbase option"
            else
                startinghostnum="$2"
                shift
            fi
            ;;
    esac
    shift
done

echo "Checking for sudo"
[ "$(id -u)" -eq 0 ] && error-exit "Do not run this script using sudo, it will use sudo when it needs to"
sudo echo "sudo access ok" || exit 1
echoverbose "Adding hostvm to /etc/hosts file if necessary"
sudo sed -i -e '/ hostvm$/d' -e '$a'"$lannetnum.1 hostvm" /etc/hosts
sudo sed -i -e '/ hostvm-mgmt$/d' -e '$a'"$mgmtnetnum.1 hostvm-mgmt puppet" /etc/hosts
#echoverbose "Adding openwrt to /etc/hosts file if necessary"
#sudo sed -i -e '/ openwrt$/d' -e '$a'"$vmintfnetnum.2 openwrt" /etc/hosts
#sudo sed -i -e '/ openwrt-mgmt$/d' -e '$a'"$mgmtnetnum.2 openwrt-mgmt" /etc/hosts

# install puppet if necessary, includes bolt install
if [ "$puppetinstall" = "yes" ]; then
    if ! systemctl is-active --quiet puppetserver 2>/dev/null; then
        [ -f ~/Downloads/puppet8-release-focal.deb ] ||
            wget -q -O ~/Downloads/puppet8-release-focal.deb https://apt.puppet.com/puppet8-release-focal.deb
        [ -f ~/Downloads/puppet8-release-focal.deb ] || error-exit "Failed to download puppet8 focal apt setup"
        sudo DEBIAN_FRONTEND=noninteractive dpkg -i ~/Downloads/puppet8-release-focal.deb || error-exit "Failed to dpkg install puppet8-release-focal.deb"
        sudo apt-get -qq update || error-exit "Failed apt update"
        sudo NEEDRESTART_MODE=a apt-get -y install puppetserver >/dev/null || error-exit "Failed to apt install puppetserver"
        sudo systemctl start puppetserver || error-exit "Failed to start puppetserver"
        sudo grep -q 'PATH=$PATH:/opt/puppetlabs/bin' /root/.bashrc || sudo sed -i '$aPATH=$PATH:/opt/puppetlabs/bin' /root/.bashrc
    fi
    echoverbose "Ensuring ${prefix}1 apache2 install manifests are present"
    puppetmanifestsdir=/etc/puppetlabs/code/environments/production/manifests
    puppetinitfile="$puppetmanifestsdir/init.pp"
    puppetsitefile="$puppetmanifestsdir/site.pp"
    sudo chgrp student "$puppetmanifestsdir"
    sudo chmod g+w "$puppetmanifestsdir"
    [ -f "$puppetinitfile" ] || cat > "$puppetinitfile" <<EOF
class webserver {
  package { 'apache2': ensure => 'latest', }
  service { 'apache2':
    ensure => 'running',
    enable => true,
    require => Package['apache2'],
  }
}
class logserver {
  package { 'rsyslog': ensure => 'latest', }
  package { 'logwatch': ensure => 'latest', }
  service { 'rsyslog':
    ensure => 'running',
    enable => true,
    require => Package['rsyslog'],
  }
}
class linuxextras {
  package { 'sl' : ensure => "latest", }
  $mypackages = [ "cowsay", "fortune", "shellcheck", ]
  package { $mypackages : ensure => "latest", }
}
class hostips {
    host { 'hostvm' : ip => "${lannetnum}.1",}
    host { 'hostvm-mgmt' : ip => "${mgmtnetnum}.1", host_aliases => 'puppet'}
    host { 'openwrt' : ip => "${lannetnum}.2",}
    host { 'openwrt-mgmt' : ip => "${mgmtnetnum}.2", }
    host { '${prefix}1' : ip => "${vmintfnetnum}.${startinghostnum}",}
    host { '${prefix}1-mgmt' : ip => "${mgmtnetnum}.${startinghostnum}",}
    host { '${prefix}2' : ip => "${vmintfnetnum}.((${startinghostnum} + 1 ))",}
    host { '${prefix}2-mgmt' : ip => "${mgmtnetnum}.((${startinghostnum} + 1))",}
}
EOF
        [ -f "$puppetsitefile" ] || cat > "$puppetsitefile" <<EOF
node ${prefix}1.home.arpa {
    include webserver
    include linuxextras
    include hostips
}
node ${prefix}2.home.arpa {
    include logserver
    include linuxextras
    include hostips
}
node default {
    include linuxextras
}
EOF

    if ! which bolt >/dev/null; then
        echoverbose "Installing bolt"
        [ -f ~/Downloads/puppet-tools-release-"$VERSION_CODENAME".deb ] ||
            wget -q -O ~/Downloads/puppet-tools-release-"$VERSION_CODENAME".deb https://apt.puppet.com/puppet-tools-release-"$VERSION_CODENAME".deb
        [ -f ~/Downloads/puppet-tools-release-"$VERSION_CODENAME".deb ] || (echo "Failed to download bolt apt setup" ; exit 1)
        sudo DEBIAN_FRONTEND=noninteractive dpkg -i ~/Downloads/puppet-tools-release-"$VERSION_CODENAME".deb ||
            error-exit "Failed to install puppet-tools-release-$VERSION_CODENAME.deb"
        sudo apt-get -qq update || error-exit "Failed to apt update"
        sudo NEEDRESTART_MODE=a apt-get -y install puppet-bolt >/dev/null || error-exit "Failed to install puppet-bolt"
    fi
    echoverbose "Setting bolt defaults for $(whoami) to access via ssh:remoteadmin@${prefix}N-mgmt"
    if [ ! -f ~/.puppetlabs/etc/bolt/bolt-defaults.yaml ]; then
        [ -d ~/.puppetlabs/etc/bolt ] || mkdir -p ~/.puppetlabs/etc/bolt
        cat >~/.puppetlabs/etc/bolt/bolt-defaults.yaml <<EOF
inventory-config:
  ssh:
    user: remoteadmin
    host-key-check: false
    private-key: ~/.ssh/id_ed25519
EOF
    fi
fi
[ -d /opt/puppetlabs/bin ] && PATH="$PATH:/opt/puppetlabs/bin"

# install lxd and initialize if needed
lxc --version >&/dev/null || sudo apt install lxd || sudo snap install lxd || exit 1
if ! ip a s lxdbr0 >&/dev/null; then
    echoverbose "Initializing lxd"
    sudo lxd init --auto
fi
vmintfip=$(ip r|awk /$vmintf/'{print $9}')
vmintfnetnum=$(sed s/\\.[[:alnum:]]$//<<<"$vmintfip")
if [ $(wc -w <<<"$vmintfip") -ne 1 ]; then
	echoverbose "Cannot determine lxdbr0 interface address of hostvm. Must fix this first."
 	exit 1
fi
if ! ip a s lan >&/dev/null; then
    lxc network create lan ipv4.address="$lannetnum".1/24 ipv6.address=none ipv4.dhcp=false ipv6.dhcp=false ipv4.nat=false
fi
if ! ip a s mgmt >&/dev/null; then
    lxc network create mgmt ipv4.address="$mgmtnetnum".1/24 ipv6.address=none ipv4.dhcp=false ipv6.dhcp=false ipv4.nat=false
fi

##create the router container if necessary
#if ! lxc info openwrt >&/dev/null ; then
#    if ! lxc launch images:openwrt/22.03 openwrt -n "$vmintf"; then
#        echoverbose "Failed to create openwrt container!"
#        exit 1
#    fi
#    lxc network attach lan openwrt eth1
#    lxc network attach mgmt openwrt eth2
#    
#    lxc exec openwrt -- sh -c 'echo "
#config device
#    option name eth1
#
#config interface lan
#    option device eth1
#    option proto static
#    option ipaddr 192.168.16.2
#    option netmask 255.255.255.0
#    
#config device
#    option name eth2
#
#config interface private
#    option device eth2
#    option proto static
#    option ipaddr 172.16.1.2
#    option netmask 255.255.255.0
#
#" >>/etc/config/network'
#    lxc exec openwrt reboot
#fi

# we want $numcontainers containers running
numexisting=$(lxc list -c n --format csv|grep -c "$prefix")
for (( n=0;n<numcontainers - numexisting;n++ )); do
    container="$prefix$((n+1))"
    if lxc info "$container" >& /dev/null; then
        echoverbose "$container already exists"
        continue
    fi
    containervmintfip="$vmintfnetnum.$((n + startinghostnum))"
    containerlanip="$lannetnum.$((n + startinghostnum))"
    containermgmtip="$mgmtnetnum.$((n + startinghostnum))"
	if ! lxc launch ubuntu:lts "$container" -n $vmintf; then
        echoverbose "Failed to create $container container!"
        exit 1
    fi
    lxc network attach lan "$container" eth1
    lxc network attach mgmt "$container" eth2
    echoverbose "Waiting for $container to complete startup"
    while ! lxc exec "$container" -- systemctl is-active --quiet ssh 2>/dev/null; do sleep 1; done
    netplanfile=$(lxc exec "$container" ls /etc/netplan)
    lxc exec "$container" -- sh -c "cat > /etc/netplan/$netplanfile <<EOF
network:
    version: 2
    ethernets:
        eth0:
            addresses: [$containervmintfip/24]
            routes:
              - to: default
                via: $vmintfip
            nameservers:
                addresses: [$vmintfip]
                search: [home.arpa, localdomain]
        eth1:
            addresses: [$containerlanip/24]
        eth2:
            addresses: [$containermgmtip/24]
EOF
"
    lxc exec "$container" -- sh -c 'echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg'
    lxc exec "$container" chmod 600 /etc/netplan/$netplanfile
    lxc exec "$container" netplan apply
    lxc exec "$container" -- sh -c "echo $containerlanip $container >>/etc/hosts"
    lxc exec "$container" -- sh -c "echo $containermgmtip $container-mgmt >>/etc/hosts"
    
    echoverbose "Adding SSH host key for $container"
    
    [ -d ~/.ssh ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
    [ ! -f ~/.ssh/id_ed25519.pub ] && ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
    ssh-keygen -q -R "$container" 2>/dev/null >/dev/null
    ssh-keyscan -t ed25519 "$container" >>~/.ssh/known_hosts 2>/dev/null
    ssh-keygen -q -H >/dev/null 2>/dev/null

    echoverbose "Adding remote admin user '$remoteadmin' to $container"
    lxc exec "$container" -- useradd -m -c "SSH remote admin access account" -s /bin/bash -o -u 0 "$remoteadmin"
    lxc exec "$container" mkdir "/home/$remoteadmin/.ssh"
    lxc exec "$container" chmod 700 "/home/$remoteadmin/.ssh"
    lxc file push ~/.ssh/id_ed25519.pub "$container/home/$remoteadmin/.ssh/"
    lxc exec "$container" cp "/home/$remoteadmin/.ssh/id_ed25519.pub" "/home/$remoteadmin/.ssh/authorized_keys"
    lxc exec "$container" chmod 600 "/home/$remoteadmin/.ssh/authorized_keys"
    lxc exec "$container" -- chown -R "$remoteadmin" "/home/$remoteadmin"

    echoverbose "Setting $container hostname"
    lxc exec "$container" hostnamectl set-hostname "$container"
    lxc exec "$container" reboot
    echo "Waiting for $container reboot"
    while ! lxc exec "$container" -- systemctl is-active --quiet ssh 2>/dev/null; do sleep 1; done
    
    echoverbose "Adding $container to /etc/hosts file if necessary"
    sudo sed -i -e "/ $container\$/d" -e "/ $container-mgmt\$/d" /etc/hosts
    sudo sed -i -e '$a'"$containerlanip $container" -e '$a'"$containermgmtip $container-mgmt" /etc/hosts
    
    if [ "$puppetinstall" = "yes" ]; then
        echoverbose "Adding puppet server to /etc/hosts file if necessary"
        grep -q ' puppet$' /etc/hosts || sudo sed -i -e '$a'"$mgmtnetnum.1 puppet" /etc/hosts
        echoverbose "Setting up for puppet8 and installing agent on $container"
        lxc exec "$container" -- wget -q https://apt.puppet.com/puppet8-release-jammy.deb
        lxc exec "$container" -- dpkg -i puppet8-release-"$VERSION_CODENAME".deb
        lxc exec "$container" -- apt-get -qq update
        echoverbose "Restarting snapd.seeded.service can take a long time, do not interrupt it"
        lxc exec "$container" -- sh -c "NEEDRESTART_MODE=a apt-get -y install puppet-agent >/dev/null"
        lxc exec "$container" -- sed -i '$aPATH=$PATH:/opt/puppetlabs/bin' .bashrc
        lxc exec "$container" -- sed -i -e '$'"a$mgmtnetnum.1 puppet" /etc/hosts
        lxc exec "$container" -- /opt/puppetlabs/bin/puppet ssl bootstrap &
    fi

done

if [ "$puppetinstall" = "yes" ]; then
    for ((count=0; count < 10; count++ )); do
        sleep 3
        sudo /opt/puppetlabs/bin/puppetserver ca list --all |grep -q Requested &&
            sudo /opt/puppetlabs/bin/puppetserver ca sign --all &&
            break
    done

    [ $count -eq 10 ] &&
        echo "Timed out waiting for certificate request(s) from containers, wait until you see the green text for certificate requests, then do" &&
        echo "sudo /opt/puppetlabs/bin/puppetserver ca sign --all"
fi
