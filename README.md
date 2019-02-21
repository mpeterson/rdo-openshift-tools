# rdo-openshift-tools
A repo with tools to run OpenShift on RDO (or any other Openstack based cloud)

## rdo-install-openshift.sh

A wrapper around the great tool [installcentos](https://github.com/gshipley/installcentos) created by [Grant Shipley](https://github.com/gshipley). This wrapper takes care of the creation of a server on the RDO cloud that is usable to run [installcentos](https://github.com/gshipley/installcentos) and ends up being an All-In-One OpenShift ([OKD](https://www.okd.io/)) installation.

### Usage

#### Prerequisities

Your RDO cloud must meet the following requirements:

* An internal network configured
* An external network configured
* A router routing between the external and internal networks
* An SSH key configured
* OPTIONAL: A security group with INGRESS TCP/22 from 0.0.0.0/0

Additionally, your local machine must meet the following requirements:

* Have the openstack client installed:

```
sudo pip install -U python-openstackclient
```

* Have the RDO cloud Openstack RC file sourced on the prompt where the script will be run.


#### Automatic

1. Source your openstackrc

```
. openstackrc
```

2. Run the following command. Don't forget to modify the OKD_USER and OKD_PASS

```
curl https://raw.githubusercontent.com/mpeterson/rdo-openshift-tools/master/rdo-install-openshift.sh | OKD_USER=myuser OKD_PASS=mypass /bin/bash
```

#### Manual

1. Clone the repository

```
git clone https://github.com/mpeterson/rdo-openshift-tools
```

2. Define mandatory variables for the installation process

```
# User created after installation
export OKD_USER=myuser

# Password for the user
export OKD_PASS=mypass
```

3. Source your openstackrc

```
. openstackrc
```

4. Run script

```
./rdo-install-openshift.sh
```

Optionally a name for the server to be created can be provided:

```
./rdo-install-openshift.sh my-custom-server-name
```

### Options

The following environmental variables can be provided to customize the image creation:

* `OKD_DOMAIN`: Domain to be used for the OpenShift install.
* `OKD_USER`: User created after installation.
* `OKD_PASS`: Password for the user.
* `SERVER_NAME`: Server name for the Openstack nova instance.
* `OS_IMAGE`: Openstack ID of the image that will be used to create the nova instance.
* `OS_FLAVOR`: Openstack ID of the nova flavor.
* `OS_NETID`: Openstack ID of the internal network to be attached.
* `OS_EXTNETID`: Openstack ID of the external network to be attached.
* `OS_FIP`: Openstack ID of the FIP to be attached.
* `OS_SECGRP`: Openstack ID of the security group to be attached.
* `OS_KEYPAIR`: Openstack name of the SSH key to be used.
