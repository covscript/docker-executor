# Web based docker executor writting in CovScript
## `backend` folder
Containing full function program including:
+ `main` program response for receiving requests from Apache2 HTTP Server;
+ `queue` program to prevent too many requests that will occupy all compute resources;
+ `driver` prgram to monitor the status of docker container and gathering running results.

We use `MariaDB` or `MySQL` for default DMBS.
## `cgi-bin` folder
### Install Apache2 HTTP Server and CGI related modules in advance.
```
# Running after installing apache2
sudo a2enmod cgi
sudo a2enmod rewrite
sudo a2enmod headers
```
### Allow `.htaccess` in config file of Apache2
usually in `/etc/apache2/apache2.conf`
```
<Directory /var/www/>
 Options Indexes FollowSymLinks
 AllowOverride All
 Require all granted
</Directory>
```
### Allow Cross-domain Access
usually in `/etc/apache2/sites-enabled/000-default.conf`
```
Header set Access-Control-Allow-Origin *
```
### Allow www-data have execution permissions
run `sudo visudo` and past these at bottom of config file
```
www-data ALL=(root) NOPASSWD: ALL
```
## `misc` folder
`release_website.ecs` is a simple tool solve the problem that WAF cannot update the cache of `*.js` and `*.css` files in time.

To run this, please install `ecs` in advance (how to: https://unicov.cn/2022/12/14/how-to-install-ecs/).