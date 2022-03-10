#!/bin/bash
# 
# --- This script automates the deployment of KodeKloud ecommerce application

NO_COLOR="\033[0m"

####################################################
# --- Prints a given message with a specified color
# --- Arguments
# ---     Color: GREEN OR RED   
# ---     Message
####################################################
function print_message(){
    case $1 in
        "GREEN") COLOR="\033[0;32m" ;;
        "RED") COLOR="\033[0;31m" ;;
        "*") COLOR="\033[0m"
    esac

    echo -e "\n${COLOR} $2 ${NO_COLOR}"
    sleep 2 
}

####################################################
# --- Checks the status of a given service. Error and 
#     exit if service not active
# --- Arguments
# ---     Service: apache2 or mariadb   
####################################################
function check_service_status(){
    is_service_active=$(systemctl is-active $1)
    if [ "$is_service_active" = "active" ]
    then
        print_message "GREEN" "$1 service is active."
    else
        print_message "RED" "$1 service inactive"
        exit 1
    fi
}

####################################################
# --- Checks if a port is enabled in a firewalld rule
# --- Arguments
# ---     Port: Eg 3306
####################################################
function is_firewalld_rule_configured(){
    firewalld_ports=$(sudo firewall-cmd --list-all --zone=public | grep ports)
    if [[ $firewalld_ports = *$1* ]]
    then
        print_message "GREEN" "Port $1 is configured."
    else
        print_message "RED" "Port $1 not configured"
        exit 1
    fi
}

####################################################
# --- Checks if an item is present in a given webpage
# --- Arguments
# ---     Webpage
# ---     Item to be checked.
####################################################
function check_item(){
    if [[ $1 = *$2* ]]
    then
        print_message "GREEN" "$2 is available"
    else
        print_message "RED" "$2 is not available"
    fi
}

################################################# FUNCTION DEFINITION ENDS ######################################


# --- Install FirewallD
print_message "GREEN" "Installing and starting firewalld"
sudo apt install -y firewalld
sudo service firewalld start
sudo systemctl enable firewalld

# --- Check if firewalld is active
check_service_status firewalld

# --------------------------------------- Deploy and Configure Database ----------------------------------------

# --- Install and start mariadb
print_message "GREEN" "Installing and starting mariadb"
sudo apt install -y mariadb-server
sudo service mariadb start
sudo systemctl enable mariadb

# --- Check if mariadb is active
check_service_status mariadb

# --- Configure firewall for Database
print_message "GREEN" "Configuring firewall services for DB"
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp;
sudo firewall-cmd --reload

# --- Check if port 3306 is properly configured
is_firewalld_rule_configured 3306

# --- Configure Database
print_message "GREEN" "Creating DB and DB user"
cat > configure-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF
# --- EOF enables us to automatically run the script without pressing Ctrl C.

# --- Run sql script
sudo mysql < configure-db.sql

# --- Load temporary data to the db.
print_message "GREEN" "Loading the sample DB files"
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");
EOF

# --- Run sql script
sudo mysql < db-load-script.sql

# ------------------------------------ Deploy and Configure Web -----------------------------------------------

# --- Install web server and configure the firewall settings
print_message "GREEN" "Installing and configuring firewall services for the web server"
sudo apt install -y apache2 php php-mysql
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

# --- Check if port 80 is properly configured
is_firewalld_rule_configured 80

# --- Change DirectoryIndex index.html to DirectoryIndex index.php to make the php page the default page basically for httpd
# --- sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf
# --- This is already handled in apache2 >> /etc/apache2/mod-enabled/dir.conf

# --- Start Apache2
print_message "GREEN" "Starting the web server"
sudo service apache2 start
sudo systemctl enable apache2

# --- Check if apache2 is active
check_service_status apache2

# --- Download code from git
# sudo apt install -y git
print_message "GREEN" "Cloning app code from github"
git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

# --- Update index.php to use the right db server
sudo sed -i 's/172.20.1.101/localhost/g' /var/www/html/index.php

# --- Test
print_message "GREEN" "All set"
# curl http://localhost

webpage=$(curl http://localhost)

for item in Laptop Sugar VR Phone Biro
do 
   check_item "$webpage" $item 
done