#!/bin/bash

LOG_FILE="/var/log/server_setup.log"
exec > >(tee -a $LOG_FILE) 2>&1

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Load previous settings if any
if [ -f "server_setup.conf" ]; then
    source server_setup.conf
    echo "Select an option:"
    echo "1. Show service status"
    echo "2. Restart services"
    echo "3. Uninstall and clean up"
    read -p "Enter choice: " option

    case $option in
        1)
            [ "$server_type" == "1" ] && systemctl status haproxy --no-pager
            [ "$server_type" == "1" ] && systemctl status keepalived --no-pager
            [ "$server_type" == "2" ] && systemctl status nginx --no-pager
            exit 0
            ;;
        2)
            [ "$server_type" == "1" ] && systemctl restart haproxy
            [ "$server_type" == "1" ] && systemctl restart keepalived
            [ "$server_type" == "2" ] && systemctl restart nginx
            echo "Services restarted successfully."
            ;;
        3)
            apt remove --purge -y haproxy keepalived nginx certbot
            rm -rf /etc/haproxy /etc/keepalived /etc/nginx /etc/ssl/certs/nginx-selfsigned.* /etc/letsencrypt server_setup.conf
            echo "All services and configurations have been removed."
            exit 0
            ;;
        *)
            echo "Invalid option."
            exit 1
            ;;
    esac
    [ "$server_type" == "1" ] && systemctl status haproxy --no-pager
    [ "$server_type" == "1" ] && systemctl status keepalived --no-pager
    [ "$server_type" == "2" ] && systemctl status nginx --no-pager
    exit 0
fi

echo "Select the type of this server:"
echo "1. Load Balancer"
echo "2. Application Server"
read -p "Enter choice [1-2]: " server_type

read -p "Enter the domain name for the server: " domain
read -p "Enter the IP address for this server: " server_ip

echo "Select ports to activate:"
echo "1. HTTP (80)"
echo "2. HTTPS (443)"
read -p "Enter choice [1-2]: " port_choice

if [ "$port_choice" == "2" ]; then
    echo "Choose the method to setup SSL certificates:"
    echo "1. Use existing certificate paths"
    echo "2. Input certificate and key contents directly"
    echo "3. Use Certbot to obtain certificates via DNS challenge"
    echo "4. Generate a self-signed certificate"
    read -p "Select an option [1-4]: " cert_choice

    case $cert_choice in
        1)
            read -p "Enter SSL certificate file path: " ssl_cert
            read -p "Enter SSL key file path: " ssl_key
            ;;
        2)
            read -p "Enter SSL certificate content: " ssl_cert_content
            read -p "Enter SSL key content: " ssl_key_content
            ssl_cert="/etc/ssl/certs/custom.crt"
            ssl_key="/etc/ssl/private/custom.key"
            echo "$ssl_cert_content" > $ssl_cert
            echo "$ssl_key_content" > $ssl_key
            ;;
        3)
            echo "Updating system before installing Certbot..."
            apt update && apt upgrade -y
            apt install -y certbot
            echo "Please ensure your DNS records are configured as required by your DNS provider for the domain $domain"
            certbot certonly --manual --preferred-challenges dns --manual-public-ip-logging-ok --agree-tos --no-bootstrap --email admin@$domain -d $domain
            ssl_cert="/etc/letsencrypt/live/$domain/fullchain.pem"
            ssl_key="/etc/letsencrypt/live/$domain/privkey.pem"
            ;;
        4)
            echo "Generating a self-signed certificate..."
            ssl_cert="/etc/ssl/certs/${domain}_selfsigned.crt"
            ssl_key="/etc/ssl/private/${domain}_selfsigned.key"
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $ssl_key -out $ssl_cert -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=$domain"
            echo "Self-signed certificate generated at $ssl_cert and $ssl_key"
            ;;
        *)
            echo "Invalid selection, exiting."
            exit 1
            ;;
    esac

    chmod 600 $ssl_key
    chmod 644 $ssl_cert
fi

# Configure firewall
echo "Setting up firewall..."
ufw allow 80/tcp

if [ "$port_choice" == "2" ]; then
    ufw allow 443/tcp
fi

ufw reload
ufw enable

# Save configuration for future use
echo "server_type=$server_type" > server_setup.conf
echo "domain=$domain" >> server_setup.conf
echo "server_ip=$server_ip" >> server_setup.conf
echo "port_choice=$port_choice" >> server_setup.conf

if [ "$port_choice" == "2" ]; then
    echo "ssl_cert=$ssl_cert" >> server_setup.conf
    echo "ssl_key=$ssl_key" >> server_setup.conf
fi

# Additional configurations based on server type
if [ "$server_type" -eq "1" ]; then
    read -p "Enter backend server IPs (comma-separated, e.g., 10.10.10.2,10.10.10.3): " backend_ips
    read -p "Enter the active port on backend servers (e.g., 80 or 443): " backend_port

    echo "Installing and configuring HAProxy..."
    apt install -y haproxy
    systemctl enable haproxy

    # Create the combined certificate for HAProxy
    ssl_cert_combined="/etc/haproxy/haproxy.pem"
    cat "$ssl_cert" "$ssl_key" > "$ssl_cert_combined"
    chmod 644 $ssl_cert_combined

    cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull
    timeout connect 5000ms
    timeout client 30000ms
    timeout server 30000ms

frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
EOF

    # Append server entries to the backend configuration
    IFS=',' read -ra ADDR <<< "$backend_ips"
    for ip in "${ADDR[@]}"; do
        if [ "$backend_port" == "80" ]; then
            echo "    server app$ip $ip:$backend_port check" >> /etc/haproxy/haproxy.cfg
        else
            echo "    server app$ip $ip:$backend_port check ssl verify none" >> /etc/haproxy/haproxy.cfg
        fi
    done

    if [ "$port_choice" == "2" ]; then
        sed -i "/frontend http_front/a \    bind *:443 ssl crt $ssl_cert_combined" /etc/haproxy/haproxy.cfg
    fi

    systemctl restart haproxy

    echo "Installing and configuring Keepalived..."
    apt install -y keepalived
    systemctl enable keepalived

    INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n 1)
    cat > /etc/keepalived/keepalived.conf << EOF
vrrp_instance VI_1 {
    state MASTER
    interface $INTERFACE
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        $server_ip
    }
}
EOF
    systemctl restart keepalived
else
    read -p "Do you want to create a default sample HTML file? (yes/no): " create_html
    echo "Installing and configuring Nginx..."
    apt install -y nginx
    systemctl enable nginx

    # Set up Nginx configuration file
    CONFIG_FILE="/etc/nginx/sites-available/$domain"
    ln -s $CONFIG_FILE /etc/nginx/sites-enabled/

    if [ "$create_html" == "yes" ]; then
        SAMPLE_HTML="/var/www/html/index.html"
        echo "<html><body><h1>Server: $domain</h1><p>Random number: $RANDOM</p><p>Server IP: $server_ip</p><p>Current Time: $(date)</p></body></html>" > $SAMPLE_HTML
        chown www-data:www-data $SAMPLE_HTML
        chmod 644 $SAMPLE_HTML
    else
        SAMPLE_HTML="/var/www/html/index.nginx-debian.html"
    fi

    if [ "$port_choice" == "1" ]; then
        cat > $CONFIG_FILE << EOF
server {
    listen 80;
    server_name $domain;

    error_log /var/log/nginx/$domain.error.log;

    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}

EOF

    fi

    if [ "$port_choice" == "2" ]; then
        cat >> $CONFIG_FILE << EOF
server {
    listen 80;
    server_name $domain;

    error_log /var/log/nginx/$domain.error.log;

    if (\$scheme = http) {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $domain;

    error_log /var/log/nginx/$domain.error.log;

    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    location / {
        root /var/www/html;
        index index.html index.htm;
    }
}
EOF
    fi

    systemctl restart nginx
fi

# Displaying service statuses
echo "Service Statuses:"
if [ "$server_type" == "1" ]; then
    systemctl status haproxy --no-pager
    systemctl status keepalived --no-pager
else
    systemctl status nginx --no-pager
fi

echo "Setup completed successfully."
