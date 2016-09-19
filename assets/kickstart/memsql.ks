install
text

network --device ens18f0 --bootproto dhcp
lang {{ if index .group "lang" }}{{.group.lang}}{{else}}en_US.UTF-8{{end}}
keyboard {{ if index .group "keyboard" }}{{.group.keyboard}}{{else}}us{{end}}


rootpw --iscrypted {{.group.root_pass}}
firewall --disabled
auth --enableshadow --passalgo=sha512
selinux --{{ if index .group "selinux"}}{{.group.selinux}}{{else}}enforcing{{end}}
timezone --utc {{ if index .env "time-zone"}}{{.env.timezone}}{{else}}UTC{{end}}
bootloader --location=mbr --append="{{ if index .group "bootloader-append" }}{{.group.bootloader_append}}{{else}}nofb quiet splash=quiet{{end}}" {{.group.grub_pass}}
services --enabled=NetworkManager,sshd,chronyd
reboot

repo --name=centos7 --baseurl={{.env.centos_baseurl}}

# TODO
#<% if @dynamic -%>
#%include /tmp/diskpart.cfg
#<% else -%>
#<%= @host.diskLayout %>
#<% end -%>

%packages
@^compute-node-environment
@base
@core
@scientific
kexec-tools
net-tools
nfs-utils
wget
%end

%post

echo "Converting DHCP scope to static IP address"

DEVICE=`route -n|grep '^0.0.0.0'|awk '{print $8}'`
IPADDR=`ifconfig $DEVICE|grep 'inet '|awk '{sub(/addr:/,""); print $2}'`
NETMASK=`ifconfig $DEVICE|grep 'netmask'|awk '{sub(/Mask:/,""); print $4}'`
NETWORK=`ipcalc $IPADDR -n $NETMASK|awk -F= '{print $2}'`
GATEWAY=`route -n|grep '^0.0.0.0'|awk '{print $2}'`
HWADDR=`ifconfig $DEVICE| grep 'ether'| awk '{print $2}'`

cat <<EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=$HOSTNAME
GATEWAY=$GATEWAY
EOF


modprobe team
cat <<EOF > /etc/modules-load.d/team.conf
team
EOF


cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-team0
DEVICE=team0
NAME=team0
DEVICETYPE=Team
TEAM_CONFIG='{"runner":{"name":"lacp","active":true,"fast_rate":true,"tx_hash":["eth","ipv4","ipv6"]},"link_watch":{"name":"ethtool"},"ports":{"enp1s0f0":{},"enp1s0f1":{}}}'
ONBOOT=yes
BOOTPROTO=none
IPADDR=$IPADDR
GATEWAY=$GATEWAY
NETMASK=$NETMASK
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-enp1s0f0
NAME=enp1s0f0
DEVICE=enp1s0f0
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
DEVICETYPE=TeamPort
TEAM_MASTER=team0
TEAM_PORT_CONFIG='{"prio":9}'
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-enp1s0f1
NAME=enp1s0f1
DEVICE=enp1s0f1
ONBOOT=yes
BOOTPROTO=none
USERCTL=no
DEVICETYPE=TeamPort
TEAM_MASTER=team0
TEAM_PORT_CONFIG='{"prio":10}'
EOF

ifup team0


cat <<EOF>/etc/yum.repos.d/centos.repo
[centos]
name=centos {{.group.os_major}}.{{.group.os_minor}}
baseurl=http://yum.ccp.xcal.tv/repo/CentOS/{{.group.os_major}}.{{.group.os_minor}}/os/{{.group.architecture}}/RPMS/
enabled=1
gpgchck=0
[centos-updates]
name=centos {{.group.os_major}}.{{.group.os_minor}} Updates
baseurl=http://yum.ccp.xcal.tv/repo/CentOS/{{.group.os_major}}.{{.group.os_minor}}/updates/{{.group.architecture}}/RPMS/
enabled=1
gpgchck=0
EOF


cat <<EOF>>/etc/security/limits.conf
* soft NOFILE 1000000
* hard NOFILE 1000000
* soft NPROC 128000
* hard NPROC 128000
EOF

ulimit -n 1000000
ulimit -u 128000

cat <<EOF>>/etc/sysctl.conf
vm.max_map_count=1000000000
vm.min_free_kbytes=500000
vm.swappiness=0
EOF
sysctl -p

rm -rf /etc/yum.repos.d/CentOS-*
yum install -y numactl mysql --nogpgcheck
yum update --nogpgcheck -y

sed -i 's/Defaults    requiretty/###Defaults    requiretty/g' /etc/sudoers
sed -i '/###Defaults    requiretty/a Defaults:memsql !requiretty' /etc/sudoers

sed -i '/server 3.centos.pool.ntp.org iburst/a server {{.env.ntp_server}}' /etc/chrony.conf
service restart chronyd
ntpdate {{.env.ntp_server}}

systemctl enable rpcbind
systemctl enable nfs-server
systemctl start rpcbind
systemctl start nfs-server

# install and configure memsql
#cd /tmp
#wget http://172.30.130.200/viper-syseng/memsql/memsql-ops-5.0.2.tar.gz
#tar -xvzf memsql-ops-5.0.2.tar.gz
#cd memsql-ops-5.0.2

#./install.sh --memsql-installs-dir=/data --no-cluster
#memsql-ops follow -h <%= @host.params['memsql-master'] %>
#memsql-ops memsql-deploy -r leaf -P 3307 --availability-group <%= @host.params['memsql-availgroup'] || 1 %>
#memsql-ops memsql-deploy -r leaf -P 3308 --availability-group <%= @host.params['memsql-availgroup'] || 1 %>
#memsql-ops memsql-deploy -r aggregator -P 3306
#cat > /etc/logrotate.d/memsql1 <<EOF
#/data/child-3306/tracelogs/command.log /data/child-3306/tracelogs/memsql.log /data/child-3306/tracelogs/query.log {
#   daily
#   rotate 7
#   missingok
#   compress
#   sharedscripts
#   postrotate
   # Send SIGHUP to both memsqld processes
#       killall -q -s1 memsqld
#   endscript
#  }
#EOF

#cat > /etc/logrotate.d/memsql2 <<EOF
#/data/leaf-3307/tracelogs/command.log /data/leaf-3307/tracelogs/memsql.log /data/leaf-3307/tracelogs/query.log {
#   daily
#   rotate 7
#   missingok
#   compress
#   sharedscripts
#   postrotate
   # Send SIGHUP to both memsqld processes
#        killall -q -s1 memsqld
#   endscript
#  }
#EOF

#cat > /etc/logrotate.d/memsql3 <<EOF
#/data/leaf-3308/tracelogs/command.log /data/leaf-3308/tracelogs/memsql.log /data/leaf-3308/tracelogs/query.log {
#   daily
#   rotate 7
#   missingok
#   compress
#   sharedscripts
#   postrotate
   # Send SIGHUP to both memsqld processes
#        killall -q -s1 memsqld
#   endscript
#  }
#EOF

cat <<EOF>>/etc/rc.local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
EOF
chmod +x /etc/rc.d/rc.local

# Inform the build system that we are done.
echo "Informing Foreman that we are built"
wget -q -O /dev/null --no-check-certificate {{.agent.url}}/notify
exit 0

%end
