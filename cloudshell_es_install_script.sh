#!/bin/bash

REQUIRED_MONO_VERSION="5.4.1"
ES_DOWNLOAD_LINK="https://s3.amazonaws.com/alex-az/ExecutionServer.tar"
ES_INSTALL_PATH="/opt/ExecutionServer/"

ES_NUMBER_OF_SLOTS=100
cs_server_host=${1}  # "192.168.120.20"
cs_server_user=${2}  # "user"
cs_server_pass=${3}  # "password"
es_name=${4}  # "ES_NAME"


command_exists () {
    type "$1" &> /dev/null ;
}

contains() {
    string="$1"
    substring="$2"

    if test "${string#*$substring}" != "$string"
    then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

unistall_mono_old_version () {
	echo "Uninstalling old Mono..."
	yes | yum remove mono
	yes | yum autoremove
}

install_mono () {
	echo "installing mono v$REQUIRED_MONO_VERSION"
	# Obtain necessary gpg keys by running the following:
	wget http://download.mono-project.com/repo/xamarin.gpg
	# Import gpg key by running the following:
	rpm --import xamarin.gpg
	# Add Mono repository
	yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
	# Install Mono
	yes | yum install mono-complete-5.4.1.6 --skip-broken
	# Install required stuff to build cryptography package
	yes | yum -y install gcc 
	yes | yum -y install python-devel
	yes | yum -y install openssl-devel
	# Install requiered packages for the QsDriverHost
	pip install -r $ES_INSTALL_PATH/packages/VirtualEnvironment/requirements.txt
	
}

configure_systemctl_service() {
	echo "Configuring execution server as a systemctl service"
	
	# run service.sh
	chmod 755 $ES_INSTALL_PATH/service.sh
	$ES_INSTALL_PATH/service.sh $cs_server_host $cs_server_user $cs_server_pass $es_name $ES_INSTALL_PATH
	
	# enable the service - service is still not started in this point
	systemctl enable es
}

# Install Python pip
yum-complete-transaction -y --cleanup-only
yum clean all
yum makecache

yum -y install epel-release
# previous command failed
if [ $? -ne 0 ]
then
    echo "Epel-release installation failed"
    sed -i "s~#baseurl=~baseurl=~g" /etc/yum.repos.d/epel.repo
    sed -i "s~mirrorlist=~#mirrorlist=~g" /etc/yum.repos.d/epel.repo
    yum -y install epel-release
fi

yes | yum -y install python-pip
yes | pip install -U pip

# install wget 
yum -y install wget

# create installation directory
mkdir -p $ES_INSTALL_PATH

# download ES - default retry is 20
wget $ES_DOWNLOAD_LINK -O es.tar
tar -xf es.tar -C $ES_INSTALL_PATH

if [command_exists mono]
	then
		echo "Mono installed, checking version..."
		res=$(mono -V);

		if ! [contains "res" $REQUIRED_MONO_VERSION]
			then
				echo "Mono Version is not $REQUIRED_MONO_VERSION"
				unistall_mono_old_version
				install_mono
	fi
else
	install_mono
fi

# install virtualenv
pip install virtualenv

# add python path to customer.config
# python_path=$(which python)
# sed -i "s~</appSettings>~<add key='ScriptRunnerExecutablePath' value='${python_path}' />\n</appSettings>~g" customer.config

# configure the execution server as a service
configure_systemctl_service

echo "Starting execution server service"
systemctl start es

# remove downloaded binaries
rm es.tar
