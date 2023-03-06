# Web based Docker executor writting in CovScript
This backend is based on Apache2 CGI and can collect data outputs from Docker Image automatically. All HTTP requests are of type `POST`.
## 1. Folder Structural
### 1.1. `backend` folder
Containing full function program including:
+ `main` program response for receiving requests from Apache2 HTTP Server;
+ `queue` program to prevent too many requests that will occupy all compute resources;
+ `driver` prgram to monitor the status of docker container and gathering running results.

We use `MariaDB` or `MySQL` for default DMBS.

Note that you must download ODBC driver shared library manually. 
For MariaDB, you can download from [Official Website](https://mariadb.com/kb/en/mariadb-connector-odbc/).

In practice, the ODBC driver `libmaodbc.so` often needs `libmariadb-dev` package installed in your machine. You can use `ldd libmaodbc.so` to check the dependencies.
### 1.2. `cgi-bin` folder
 + `.htaccess` is a rewrite script for Apache2 which can enable CGI permission and redirect subdirectory access (.../executor/*functions*) to HTTP GET arguments (.../executor?*functions*);
 + `executor` is a bash script that can boot actual CovScript program.

You should put these file into your website folder (Default in `/var/www/html` for Apache2).
### 1.3. `misc` folder
`release_website.ecs` is a simple tool solve the problem that WAF cannot update the cache of `*.js` and `*.css` files in time.

To run this, please install `ecs` in advance (how to: https://unicov.cn/2022/12/14/how-to-install-ecs/).
## 2. Prepare Environment
### 2.1. Install Apache2
```
sudo apt install apache2
```
#### Enable CGI related modules
```
# Running after installing apache2
sudo a2enmod cgi
sudo a2enmod rewrite
sudo a2enmod headers
```
#### Allow `.htaccess` in config file of Apache2
usually in `/etc/apache2/apache2.conf`
```
<Directory /var/www/>
 Options Indexes FollowSymLinks
 AllowOverride All
 Require all granted
</Directory>
```
#### Allow Cross-domain Access
usually in `/etc/apache2/sites-enabled/000-default.conf`
```
Header set Access-Control-Allow-Origin *
```
#### Allow www-data have execution permissions
run `sudo visudo` and past these at bottom of config file
```
www-data ALL=(root) NOPASSWD: ALL
```
### 2.2. Install Docker
```
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```
#### *Enable CUDA Support for Docker (Optional)*
```
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```
Test CUDA with PyTorch
```
sudo docker run --gpus all -it --rm nvcr.io/nvidia/pytorch:22.08-py3
python
>>> import torch
>>> print(torch.cuda.is_available())
```
### 2.3. Install CovScript
```
wget http://mirrors.covariant.cn/covscript/covscript-amd64.deb
sudo dpkg -i covscript-amd64.deb
```
#### Install Dependencies
```
cspkg install --import
cspkg install csdbc_mysql --yes
cspkg install ecs_bootstrap --yes
```