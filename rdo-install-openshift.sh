#!/bin/bash

if [ -z "$OS_AUTH_URL" ]; then
    echo "ERROR: Please source your Openstack RC file"
    exit 1
fi

if [ -z "$OKD_USER" ] || [ -z "$OKD_PASS" ]; then
   echo "ERROR: OKD_USER and OKD_PASS should be set to create the initial OpenShift user."
   exit 1
fi

echo "Preparing for server creation..."
export SERVER_NAME=${1:-"okd-$(date|sha256sum|head -c 5)"}
export OS_IMAGE=${OS_IMAGE:-fdfd5d39-a76d-45df-abec-17f768ba3054}
export OS_FLAVOR=${OS_FLAVOR:-m1.large2}

echo "  | Retrieving internal network..."
export OS_NETID=${OS_NETID:-$(openstack network list --internal -f value -c ID| head -n 1)}
echo "  | Retrieving external network..."
export OS_EXTNETID=${OS_EXTNETID:-$(openstack network list --external -f value -c ID| head -n 1)}
echo "  | Retrieving available FIPs..."
export OS_FIP=$(openstack floating ip list --status DOWN -f value -c 'Floating IP Address'|head -n1)
echo "  | Retrieving security groups..."
export OS_SECGRP=${OS_SECGRP:-$(openstack security group rule list --ingress --protocol tcp -f value |awk '/0.0.0.0\/0/ {split($4,port,":"); if(22>=port[1] && 22<=port[2]){print $6}}'|head -n 1)}
echo "  | Retrieving SSH keypair..."
export OS_KEYPAIR=${OS_KEYPAIR:-$(openstack keypair list -f value -c Name|head -n 1)}


if [ -z "$OS_NETID" ] || [ -z "$OS_EXTNETID" ]; then
   echo "ERROR: Internal or External networks are not configured properly."
   exit 1
fi

if [ -z "$OS_KEYPAIR" ]; then
   echo "ERROR: Could not find a SSH keypair to provide SSH access with."
   exit 1
fi

if [ -z "$OS_FIP" ]; then
    export OS_FIP=$(openstack floating ip create $OS_EXTNETID -f value -c floating_ip_address)

    if [ $? -ne 0 ]; then
        echo "ERROR: Could not create a FIP to be used."
        exit 1
    fi
fi


cat > /tmp/cloud-install-openshift.sh << EOFCLOUD
#!/bin/bash

yum install -y tmux

cd /home/centos

cat > provision-openshift.sh <<EOF
#!/bin/bash
export DOMAIN=${OKD_DOMAIN:-$OS_FIP.nip.io}
export USERNAME=$OKD_USER
export PASSWORD=$OKD_PASS
curl -s https://raw.githubusercontent.com/gshipley/installcentos/master/install-openshift.sh | INTERACTIVE=false sudo -E USERNAME=\\\$USERNAME bash
EOF

chown centos:centos provision-openshift.sh
chmod +x provision-openshift.sh

sudo -u centos tmux new-session -d -s install-openshift 'bash ./provision-openshift.sh 2>&1|tee provision-openshift.log'
sudo -u centos tmux set-option -t install-openshift remain-on-exit on
EOFCLOUD

chmod +x /tmp/cloud-install-openshift.sh

OPT_SECGRP="--security-group default"
if [ ! -z "$OS_SECGRP" ]; then
    OPT_SECGRP+=" --security-group $OS_SECGRP"
fi

echo "Starting server creation..."
echo "  | Creating server..."
openstack server create --flavor $OS_FLAVOR $OPT_SECGRP --key-name "$OS_KEYPAIR" --image $OS_IMAGE --nic net-id=$OS_NETID --user-data /tmp/cloud-install-openshift.sh $SERVER_NAME > /tmp/$SERVER_NAME-creation.log 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Server could not be created. View logs at /tmp/$SERVER_NAME-creation.log"
    exit 1
fi

echo "  | Assigning FIP..."
openstack server add floating ip $SERVER_NAME $OS_FIP > /tmp/$SERVER_NAME-fip.log 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Server could not be assigned a FIP. View logs at /tmp/$SERVER_NAME-fip.log"
    exit 1
fi



echo
echo "Server created with the name: $SERVER_NAME"
echo

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
MSG="can access your server by ssh-ing into it:

    ssh $SSH_OPTS centos@$OS_FIP"

if [ -z "$OS_SECGRP" ]; then
    echo "There was no Security Group with SSH access. Please create one, assign it to this server and then you $MSG"
    echo
    echo 'This can be done by executing:'
    echo
    echo "openstack server add security group $SERVER_NAME \$(openstack security group rule create --dst-port 22 -f value -c id \$(openstack security group create 'SSH' -f value -c id))"
else
    echo "You $MSG"
fi

echo
echo 'Once ssh-ed into the server, view the installation progress by running:

    tmux a -t install-openshift

It will take approximate 30 minutes to finish the installation'
