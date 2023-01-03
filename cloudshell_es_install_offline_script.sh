#!/bin/bash
############################################################
#                          Help                            #
############################################################
Help()
{
    # Display Help
    echo "Execution Server installation."
    echo
    echo "Syntax: $0 [-h|s|u|p|n]"
    echo "Mandatory options:"
    echo "h     Print this Help."
    echo "s     Cloudshell Server Address."
    echo "u     Cloudshell Server User."
    echo "p     Cloudshell Server Password."
    echo "n     Execution Server Name."
    echo
}

############################################################
#                        Variables                         #
############################################################
ES_INSTALL_PATH="/opt/ExecutionServer/"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

############################################################
#                        Methods                           #
############################################################
configure_systemctl_service() {
	echo "Configuring execution server as a systemctl service"

	# run service.sh
	chmod 755 $ES_INSTALL_PATH/service.sh
	$ES_INSTALL_PATH/service.sh $cs_server_host $cs_server_user $cs_server_pass $es_name $ES_INSTALL_PATH

	# enable the service - service is still not started in this point
	systemctl enable es
}

install_python2718() {
    echo "Installing Python 2.7.18"
    cd /usr/src
    cp $SCRIPT_PATH/Python-2.7.18.tgz ./
    tar xzf Python-2.7.18.tgz
    cd Python-2.7.18
    ./configure --enable-optimizations
    make altinstall
    rm -f /usr/src/Python-2.7.18.tgz

    /usr/local/bin/python2.7 -m ensurepip  # will install pip and setuptools
    # Install required packages for the QsDriverHost
    /usr/local/bin/python2.7 -m pip install --no-index --find-links $ES_INSTALL_PATH/packages/VirtualEnvironment/ -r $ES_INSTALL_PATH/packages/VirtualEnvironment/requirements.txt
    # create symlink for python
    ln -s /usr/local/bin/python2.7 /usr/local/bin/python
}


install_python3() {
    echo "Installing Python 3.9.9"
    cd /usr/src
    cp $SCRIPT_PATH/Python-3.9.9.tgz ./
    tar xzf Python-3.9.9.tgz
    cd Python-3.9.9
    ./configure --prefix=/usr --enable-optimizations
    make altinstall
    rm -f /usr/src/Python-3.9.9.tgz

    # create symlink for python3
    PYTHON3_PATH=/usr/bin/python3
    if [ -L $PYTHON3_PATH ];
    then
        rm -f $PYTHON3_PATH
    fi
    ln -s /usr/bin/python3.9 $PYTHON3_PATH
}

############################################################
############################################################
#                      Main program                        #
############################################################
############################################################

############################################################
#                 Process the input options                #
############################################################

if [ ! -f $SCRIPT_PATH/ExecutionServer.tar ]
then
    echo -e "\033[0;31m File does not exist in Bash \033[0m";
    exit 1
fi

while getopts h:s:u:p:n: flag
do
    case "${flag}" in
        h) # Display Help and exit
           Help; exit 1;;
        s) cs_server_host=${OPTARG};; # Set Cloudshell Server Host
        u) cs_server_user=${OPTARG};; # Set Cloudshell Server Username
        p) cs_server_pass=${OPTARG};; # Set Cloudshell Server Password
        n) es_name=${OPTARG};;        # Set Execution Server Name
        \?) # Raise error, display Help and exit
           echo -e "\033[0;31m Error: Invalid option provided \033[0m"; Help; exit 1;;
    esac
done

if ((OPTIND == 1))
then
    echo -e "\033[0;31m Error: No options specified \033[0m";
    Help;
    exit 1
fi

if [ -z "$es_name" ]; then
    echo -e "\033[0;33m Execution Server Name is missing. Set name as hostname. \033[0m";
    es_name=$(hostname)
fi

if [ -z "$cs_server_user" ]; then
    echo -e "\033[0;33m Quali Server User is missing. Set to default: admin \033[0m";
    cs_server_user="admin"
fi

if [ -z "$cs_server_pass" ]; then
    echo -e "\033[0;33m Quali Server Password is missing. Set to default: admin \033[0m";
    cs_server_pass="admin"
fi

# Create installation directory
mkdir -p $ES_INSTALL_PATH

# Unpack ExecutionServer archive to installation directory
tar -xf ExecutionServer.tar -C $ES_INSTALL_PATH

# Try to remove existed mono installation
echo "Uninstalling old Mono..."
yum remove mono
yum autoremove

# Install all necessary rpm-packages
echo -n "Installing all necessary RPM-packages... "
yum --disablerepo=* localinstall ./rpm_pkgs/*.rpm -y --skip-broken

# Install Python 2
echo -n "checking if Python 2.7.18 is installed... "
version=$(python -V 2>&1 | grep -Po '(?<=Python )(.+)')
parsedVersion=$(echo "${version//./}")
if [[ "$parsedVersion" -ne "2718" ]]
then
    echo "no"
    install_python2718
fi

# Install Python 3
echo -n "checking if Python 3 is installed... "
if ! [type python3 &> /dev/null]
    then
        echo "no"
        install_python3
else
    echo "yes"
fi

# Install python packages
/usr/local/bin/python -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/pip-19.2.3-py2.py3-none-any.whl -U
/usr/local/bin/python -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/virtualenv-20.13.0-py2.py3-none-any.whl -U
/usr/local/bin/python -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/wheel-0.37.1-py2.py3-none-any.whl -U
python3 -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/pip-21.2.4-py3-none-any.whl -U
python3 -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/virtualenv-20.13.0-py2.py3-none-any.whl -U
python3 -m pip install --no-index --find-links $SCRIPT_PATH/python_pkgs $SCRIPT_PATH/python_pkgs/wheel-0.37.1-py2.py3-none-any.whl -U

# configure the execution server as a service
configure_systemctl_service

echo "Starting execution server service"
systemctl start es
