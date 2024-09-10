#!/bin/bash

# Script to completely uninstall and purge Dovecot and its configuration files

# Stop Dovecot service
echo "Stopping Dovecot service..."
sudo systemctl stop dovecot

# Disable Dovecot service
echo "Disabling Dovecot service..."
sudo systemctl disable dovecot

# Purge Dovecot packages
echo "Purging Dovecot packages..."
sudo apt-get purge --auto-remove dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd dovecot-sieve dovecot-managesieved

# Remove Dovecot user and group
echo "Removing Dovecot user and group..."
sudo deluser dovecot
sudo delgroup dovecot

# Remove remaining configuration and log files
echo "Deleting Dovecot configuration and log files..."
sudo rm -rf /etc/dovecot
sudo rm -rf /var/lib/dovecot
sudo rm -rf /var/log/dovecot
sudo rm -rf /usr/share/dovecot

# Optionally remove mail directory if it's specifically for Dovecot (BE CAREFUL)
# Uncomment the following line if you're sure you want to delete all mail directories associated with Dovecot
# sudo rm -rf /var/mail /home/*/Maildir

# Clean up the apt cache
echo "Cleaning up the apt cache..."
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "Dovecot has been completely removed from your system."
