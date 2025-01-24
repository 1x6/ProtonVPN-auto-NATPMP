#!/bin/bash

service_file="/etc/systemd/system/multi-user.target.wants/qbittorrent-nox@user.service"
service="qbittorrent-nox@user"
api_base_url="http://localhost:8080/api/v2/app"
wireguard_interface="wireguardconfig"
wireguard_config="/home/user/wireguardconfig.conf"

sudo wg-quick up $wireguard_config
while true; do
    date

    if sudo wg show | grep -q $wireguard_interface; then
        echo "Wireguard interface is up"
    else
        echo "Wireguard interface not found. Restarting Wireguard..."
        sudo wg-quick down $wireguard_config
        sudo wg-quick up $wireguard_config
    fi

    natpmpc -a 1 0 udp 60 -g 10.2.0.1 > /tmp/natpmpc_output && natpmpc -a 1 0 tcp 60 -g 10.2.0.1 > /tmp/natpmpc_output || { 
        echo -e "ERROR with natpmpc command \a" 
        break
    }

    port=$(grep 'TCP' /tmp/natpmpc_output | grep -o 'Mapped public port [0-9]*' | awk '{print $4}')
    echo "Opened port: $port"

    old_port=$(curl -s -X GET "$api_base_url/preferences" | grep -o '"listen_port":[0-9]*' | grep -o '[0-9]*')
    echo "The listening port is: $old_port"

    current_network_interface=$(curl -s -X GET "$api_base_url/preferences" | grep -o '"current_network_interface": *"[^"]*"' | awk -F ':"' '{print $2}' | tr -d '"')
    echo "Current network interface: $current_network_interface"

    if [ "$current_network_interface" != "$wireguard_interface" ]; then
        echo "Current network interface is different. Changing to $wireguard_interface"
        curl -i -X POST -d "json={\"current_network_interface\": \"$wireguard_interface\"}" "$api_base_url/setPreferences"
        echo "Sent request to change network interface"
        sudo systemctl restart $service
        echo "Service restarted"
    fi
    
    echo "The listening port is: $old_port"

    if [ "$old_port" != "$port" ]; then
        echo "Current port is different. Changing to $port"
        curl -i -X POST -d "json={\"listen_port\": $port}" "$api_base_url/setPreferences"
        echo "Sent request to change port"
        sudo systemctl restart $service
        echo "Service restarted"
    fi
    sleep 45
done
