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
ES_DOWNLOAD_LINK="https://quali-prod-binaries.s3.amazonaws.com/2022.2.0.1489-184885/ES/exec.tar"
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

install_deb_packages() {
    # Try to remove existed mono installation
    echo "Uninstalling old Mono..."
    apt remove mono
    apt autoremove -y

    # Add Xamarin repo
    apt install gnupg ca-certificates
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
    echo "deb https://download.mono-project.com/repo/ubuntu stable-focal main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list
    apt update

    # Install Mono
    apt install mono-complete=6.12.* -y

    # Install all necessary deb-packages
    echo "Installing all necessary DEB-packages... "
    apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev zlib* python-pip -y
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

    # create symlink for python
    ln -s /usr/local/bin/python2.7 /usr/local/bin/python

    # Install pip and setuptools
    /usr/local/bin/python -m ensurepip
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

install_deb_packages

lsb_release_path=$(which lsb_release)
if [ -n "$lsb_release_path" ]; then
    mv $lsb_release_path $lsb_release_path.backup
fi


# Download and Unpack ExecutionServer archive to installation directory
wget $ES_DOWNLOAD_LINK -O ExecutionServer.tar
tar -xf ExecutionServer.tar -C $ES_INSTALL_PATH

# Install Python 2
echo -n "Checking if Python 2.7.18 is installed... "
version=$(python -V 2>&1 | grep -Po "(?<=Python )(.+)" | sed "s/\.//g")
if [ -z "$version" ]; then
    version=$(python2 -V 2>&1 | grep -Po "(?<=Python )(.+)" | sed "s/\.//g")
    if [[ "$version" -ne "2718" ]]
    then
        echo "no"
        install_python2718
    else
        ln -s $(which python2) /usr/local/bin/python
    fi
else
    if [[ "$version" -ne "2718" ]]
    then
        echo "no"
        install_python2718
    fi
fi

# Install Python 3
echo -n "Checking if Python 3 is installed... "
if ! [type python3 &> /dev/null]
    then
        echo "no"
        install_python3
else
    echo "yes"
fi

# Install required packages for the QsDriverHost
/usr/local/bin/python -m pip install --no-index --find-links $ES_INSTALL_PATH/packages/VirtualEnvironment/ -r $ES_INSTALL_PATH/packages/VirtualEnvironment/requirements.txt

# Install python packages
/usr/local/bin/python -m pip install pip==19.2.3 -U
/usr/local/bin/python -m pip install virtualenv==20.13.0 -U
/usr/local/bin/python -m pip install wheel==0.37.1 -U
python3 -m pip install pip==21.2.4 -U
python3 -m pip install virtualenv==20.13.0 -U
python3 -m pip install wheel==0.37.1 -U

# Configure the execution server as a service
configure_systemctl_service

echo "Starting execution server service"
systemctl start es
