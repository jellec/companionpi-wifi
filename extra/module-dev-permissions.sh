#!/bin/bash

echo "This script will set rwx permission to the /opt/companion-module-dev folder. This folder is for custom companion modules."

# Create the group
sudo groupadd allusers

# Add users to the group
sudo usermod -a -G allusers pi
sudo usermod -a -G allusers companion

# Change group ownership
sudo chown :allusers /opt/companion-module-dev

# Set permissions to rwxrwxr-x
sudo chmod 775 /opt/companion-module-dev


