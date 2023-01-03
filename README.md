# Execution-Server-Cloud-Installer

The content of this repository is not intended to be used "as is". Please refer to the [download center](https://support.quali.com/hc/en-us/articles/231613247).

## Cloudshell Execution Server installation Script package structure

- cloudshell_es_install_offline_script.sh
- ExecutionServer.tar
- Python-2.7.18.tgz
- Python-3.9.9.tgz
- rpm_pkgs
    - binutils.rpm
    - mono-complete-5.16.0.220-0.xamarin.4.epel7.x86_64.rpm
    - ...
- python_pkgs
    - pip-19.2.3-py2.py3-none-any.whl
    - virtualenv-20.13.0-py2.py3-none-any.whl
    - wheel-0.37.1-py2.py3-none-any.whl
    - ...
    
## Cloudshell Execution Server installation Script package structure
### Download Execution Server
**_Note: Quali Server and Execution Server have to be the same version_**

For example to download Execution Server 2022.2 use command:

`wget https://quali-prod-binaries.s3.amazonaws.com/2022.2.0.1489-184885/ES/exec.tar -O ExecutionServer.tar`

### Download Python
#### Python 2
`wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz`

#### Python 3
`wget https://www.python.org/ftp/python/3.9.9/Python-3.9.9.tgz`


### Adding Xamarin repo
`curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo`
### Download RPM-packages
`yumdownloader --resolve yum-utils make mono-complete-5.16.0.220 gcc python2-devel python3-devel openssl-devel zlib zlib-devel libffi-devel python2-pip python3-pip`
### Download Python-packages
#### Python 2 packages
```
pip2 download pip==19.2.3
pip2 download virtualenv==20.13.0
pip2 download wheel==0.37.1
```
#### Python 3 packages
```
pip2 download pip==21.2.4
pip2 download virtualenv==20.13.0
pip2 download wheel==0.37.1
```