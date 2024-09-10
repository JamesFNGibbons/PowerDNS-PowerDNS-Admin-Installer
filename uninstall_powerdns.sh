#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DB_ROOT_PASS="root_password"         # Set your MySQL root password
PDNS_ADMIN_DIR="/opt/powerdns-admin"
SERVICES=("pdns" "powerdns-admin")

# Function to print messages
log() {
  echo -e "\n\e[1;34m$1\e[0m\n"
}

# Function to check and stop a service if it exists
check_and_stop_service() {
  local service=$1
  if systemctl list-units --type=service --state=running | grep -q "$service.service"; then
    log "Stopping and disabling $service service..."
    sudo systemctl stop "$service"
    sudo systemctl disable "$service"
  else
    log "$service service is not running or does not exist."
  fi
}

log "Checking and stopping PowerDNS and PowerDNS-Admin services..."

# Check and stop PowerDNS and PowerDNS-Admin services if they exist
for service in "${SERVICES[@]}"; do
  check_and_stop_service "$service"
done

log "Removing PowerDNS and PowerDNS-Admin..."

# Remove PowerDNS and PowerDNS-Admin packages
sudo apt-get remove --purge -y pdns-server pdns-backend-mysql
sudo apt-get autoremove -y

log "Removing PowerDNS-Admin directory..."

# Remove PowerDNS-Admin directory
sudo rm -rf $PDNS_ADMIN_DIR

log "Removing MySQL and its data..."

# Remove MySQL server and its data
sudo apt-get remove --purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
sudo apt-get autoremove -y
sudo apt-get autoclean -y

# Remove MySQL data and configuration
sudo rm -rf /etc/mysql
sudo rm -rf /var/lib/mysql
sudo rm -rf /var/log/mysql
sudo rm -rf /var/lib/mysql-files
sudo rm -rf /var/lib/mysql-keyring
sudo rm -rf /var/lib/mysql-cluster

# Optionally remove MySQL user
sudo deluser mysql
sudo delgroup mysql

log "Removing configuration files..."

# Remove PowerDNS configuration files
sudo rm -f /etc/powerdns/pdns.conf

# Remove systemd service files
sudo rm -f /etc/systemd/system/powerdns-admin.service

log "Cleaning up remaining files..."

# Clean up remaining files and directories
sudo rm -rf /var/lib/powerdns
sudo rm -rf /var/log/pdns

# Restore resolv.conf if needed
if [ -f /etc/resolv.conf.backup ]; then
  sudo mv /etc/resolv.conf.backup /etc/resolv.conf
fi

log "Cleanup complete!"
