#!/bin/bash

REQUIRED_MONO_VERSION="4.0.1"
ES_DOWNLOAD_LINK="https://cf-dynamic-execution-server.s3.amazonaws.com/execution-server/ExecutionServer.tar"
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
	# Install yum-utils
	if ! [command_exists yum-config-manager]
	then
		echo "Installing yum-utils"
		yes | yum install yum-utils
	fi
	# Add Mono repository
	yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
	# Install Mono
	# yes | yum install mono-devel-4.0.1 --skip-broken  -- not needed
	yes | yum install mono-complete-4.0.1 --skip-broken
	# Install required stuff to build cryptography package
	yes | yum -y install gcc 
	yes | yum -y install python-devel
	yes | yum -y install openssl-devel
	# Install requiered packages for the QsDriverHost
	pip install -r $ES_INSTALL_PATH/packages/VirtualEnvironment/requirements.txt
	
}

#setup_supervisor() {
#	# Install Needed Package
#	yes | yum install python-setuptools
#	yes | yum install supervisor
#	# create config file
#	echo_supervisord_conf > /etc/supervisord.conf
#	echo -e '\n[program:cloudshell_execution_server]\ndirectory='$ES_INSTALL_PATH'\ncommand=/bin/bash -c "/usr/bin/mono QsExecutionServerConsoleConfig.exe /s:'$cs_server_host' /u:'$cs_server_user' /p:'$cs_server_pass' /esn:'$es_name' /i:'$ES_NUMBER_OF_SLOTS' && /usr/bin/mono QsExecutionServer.exe console"\nenvironment=MONO_IOMAP=all\n' >> /etc/supervisord.conf
#	setenforce 0
#	systemctl enable supervisord.service
#}

configure_systemctl_service() {
	echo "configuring execution server as a systemctl service"
	# create service config file
	echo -e '[Unit]\nDescription=CloudShell Execution Server Service\nAfter=network.target\n\n[Service]\nType=simple\nUser=root\nEnvironment=MONO_IOMAP=all\nWorkingDirectory=/opt/ExecutionServer\nExecStart=/bin/bash -c "/usr/bin/mono QsExecutionServerConsoleConfig.exe /s:'$cs_server_host' /u:'$cs_server_user' /p:'$cs_server_pass' /esn:'$es_name' /i:'$ES_NUMBER_OF_SLOTS' && /usr/bin/mono-service -d:/opt/ExecutionServer /opt/ExecutionServer/QsExecutionServer.exe --no-daemon"\nRestart=on-abort\n\n[Install]\nWantedBy=multi-user.target\n' > /usr/lib/systemd/system/qs_execution_server.service
	# reload systemctl
	systemctl daemon-reload
	# enable the service - service is still not started in this point
	systemctl enable qs_execution_server
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

#setup_supervisor

# install virtualenv
pip install virtualenv

# add python path to customer.config
# python_path=$(which python)
# sed -i "s~</appSettings>~<add key='ScriptRunnerExecutablePath' value='${python_path}' />\n</appSettings>~g" customer.config

# configure the execution server as a service
configure_systemctl_service

echo "starting execution server service"
systemctl start qs_execution_server

rm es.tar
