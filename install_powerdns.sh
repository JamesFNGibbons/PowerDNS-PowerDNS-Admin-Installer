#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DB_ROOT_PASS="root_password"         # Set your MySQL root password
DB_PDNS_PASS="pdns_password"         # Set a strong password for the PowerDNS database user
PDNS_DB="pdns"                       # Database name for PowerDNS
PDNS_USER="pdns"                     # MySQL username for PowerDNS
PDNS_ADMIN_DB="powerdnsadmin"        # Database name for PowerDNS-Admin
PDNS_ADMIN_USER="pdnsadmin"          # MySQL username for PowerDNS-Admin
PDNS_ADMIN_PASS="pdnsadmin_password" # Password for PowerDNS-Admin MySQL user
PDNS_ADMIN_REPO="https://github.com/PowerDNS-Admin/PowerDNS-Admin.git"
PDNS_ADMIN_DIR="/opt/powerdns-admin"

# Function to print messages
log() {
  echo -e "\n\e[1;34m$1\e[0m\n"
}

log "Updating and upgrading system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

log "Installing MySQL server..."
sudo apt-get install -y mysql-server

log "Securing MySQL installation..."
sudo mysql_secure_installation

log "Creating PowerDNS database and user..."
sudo mysql -u root -p$DB_ROOT_PASS <<EOF
CREATE DATABASE $PDNS_DB;
CREATE USER '$PDNS_USER'@'localhost' IDENTIFIED BY '$DB_PDNS_PASS';
GRANT ALL PRIVILEGES ON $PDNS_DB.* TO '$PDNS_USER'@'localhost';
CREATE DATABASE $PDNS_ADMIN_DB;
CREATE USER '$PDNS_ADMIN_USER'@'localhost' IDENTIFIED BY '$PDNS_ADMIN_PASS';
GRANT ALL PRIVILEGES ON $PDNS_ADMIN_DB.* TO '$PDNS_ADMIN_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

log "Installing PowerDNS and MySQL backend module..."
sudo apt-get install -y pdns-server pdns-backend-mysql

log "Configuring PowerDNS to use MySQL backend..."
sudo sed -i 's/^# launch=.*/launch=gmysql/' /etc/powerdns/pdns.conf
sudo sed -i "s/^# gmysql-host=.*/gmysql-host=localhost/" /etc/powerdns/pdns.conf
sudo sed -i "s/^# gmysql-user=.*/gmysql-user=$PDNS_USER/" /etc/powerdns/pdns.conf
sudo sed -i "s/^# gmysql-password=.*/gmysql-password=$DB_PDNS_PASS/" /etc/powerdns/pdns.conf
sudo sed -i "s/^# gmysql-dbname=.*/gmysql-dbname=$PDNS_DB/" /etc/powerdns/pdns.conf

log "Importing PowerDNS schema into MySQL..."
sudo wget -qO- https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema/schema.mysql.sql | sudo mysql -u $PDNS_USER -p$DB_PDNS_PASS $PDNS_DB

log "Restarting PowerDNS service..."
sudo systemctl restart pdns

log "Enabling PowerDNS service to start on boot..."
sudo systemctl enable pdns

log "Installing dependencies for PowerDNS-Admin..."
sudo apt-get install -y git python3-pip python3-dev python3-venv libmysqlclient-dev libssl-dev libffi-dev pkg-config libpq-dev libldap2-dev libsasl2-dev

log "Installing Python3 FLASK"
sudo apt-get install python3-flask
sudo apt-get install python3-flask-mail
sudo apt-get install python3-flask-session
sudo apt-get install python3-flask-migrate

log "Installing other python3 sys wide libs"
sudo apt-get install python3-pyotp

log "Cloning PowerDNS-Admin repository..."
sudo git clone $PDNS_ADMIN_REPO $PDNS_ADMIN_DIR

log "Creating and activating Python virtual environment..."
python3 -m venv $PDNS_ADMIN_DIR/venv
source $PDNS_ADMIN_DIR/venv/bin/activate

log "Installing Python dependencies..."
pip install -r $PDNS_ADMIN_DIR/requirements.txt

log "Replacing psycopg2 with psycopg2-binary in requirements..."
sed -i "s/psycopg2==.*/psycopg2-binary==2.9.5/" $PDNS_ADMIN_DIR/requirements.txt
pip install -r $PDNS_ADMIN_DIR/requirements.txt

log "Configuring PowerDNS-Admin..."
sudo bash -c 'cat <<EOF > /opt/powerdns-admin/config.py
SQLALCHEMY_DATABASE_URI = "mysql+pymysql://pdnsadmin:pdnsadmin_password@localhost/powerdnsadmin"
SECRET_KEY = "your_secret_key"
EOF'

log "Creating PowerDNS-Admin systemd service..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/powerdns-admin.service
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=root
ExecStart=/opt/powerdns-admin/venv/bin/python /opt/powerdns-admin/run.py
WorkingDirectory=/opt/powerdns-admin
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

log "Starting and enabling PowerDNS-Admin service..."
sudo systemctl daemon-reload
sudo systemctl start powerdns-admin
sudo systemctl enable powerdns-admin

log "PowerDNS and PowerDNS-Admin installation and configuration complete!"
log "You can access PowerDNS-Admin via http://your_server_ip:9191"
