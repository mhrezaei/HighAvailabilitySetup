# HighAvailabilitySetup

## Introduction
This repository contains Bash scripts designed to automate the deployment of high-availability configurations for servers using HAProxy, Keepalived, and Nginx, along with SSL setups. These tools work in tandem to ensure that your web services are both reliable and secure.

## Compatibility
This script is specifically tailored for Ubuntu operating systems. It utilizes Ubuntu's package management and configuration standards to install and configure HAProxy, Keepalived, and Nginx.

## How to Install
To run the installation script from this repository, execute the following command in your terminal:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/mhrezaei/HighAvailabilitySetup/master/install.sh)
```
This command will download and run the installation script directly.

## Components and Their Roles
- **HAProxy**: Acts as a load balancer, distributing incoming network traffic across multiple servers to improve the availability and reliability of your application's services.
- **Keepalived**: Uses VRRP (Virtual Router Redundancy Protocol) to ensure high availability by preventing a single point of failure in the load balancer setup.
- **Nginx**: Serves as a web server and reverse proxy, handling client requests efficiently and serving content from your application.

## How to Use
Upon execution, the script prompts you to provide specific configuration details interactively:

### Initial Setup
1. **Server Type Selection**:
    - **Prompt**: "Select the type of this server:"
    - **Options**:
        - `1` for Load Balancer: Distributes network traffic to multiple backend servers.
        - `2` for Application Server: Directly hosts web applications.
    - **Example**: `Enter choice [1-2]: 1`

2. **Domain Name**:
    - **Prompt**: "Enter the domain name for the server:"
    - **Example**: `example.com`

3. **Server IP Address**:
    - **Prompt**: "Enter the IP address for this server:"
    - **Example**: `192.168.1.100`

4. **Ports Activation**:
    - **Prompt**: "Select ports to activate:"
    - **Options**:
        - `1` for HTTP
        - `2` for HTTPS
    - **Example**: `Enter choice [1-2]: 2`

### SSL Certificate Setup (if HTTPS is selected)
- **Prompt**: "Choose the method to setup SSL certificates:"
- **Options**:
    1. **Use Existing Certificate Paths**: Provide paths to your existing SSL certificate and key.
    2. **Input Certificate and Key Contents Directly**: Enter the contents of your SSL certificate and key.
    3. **Use Certbot**: Obtain certificates automatically via DNS challenge with Certbot.
    4. **Generate a Self-Signed Certificate**: For testing or internal use.
- **Example for Existing Paths**:
    - `Enter SSL certificate file path: /etc/ssl/certs/server.crt`
    - `Enter SSL key file path: /etc/ssl/private/server.key`

### Additional Setup for Load Balancers
- **Prompt**: "Enter backend server IPs (comma-separated):"
- **Example**: `192.168.1.101,192.168.1.102`

### Subsequent Uses
Running the script after the initial setup offers a menu with options to:
1. **Show Service Statuses**: Checks and displays the status of HAProxy, Keepalived, and Nginx.
2. **Restart Services**: Restarts all relevant services based on the server type selected.
3. **Uninstall**: Removes all installations, configurations, and cleans up installed files.

## Reporting Bugs
Encounter any issues? Please report them in the [Issues section](https://github.com/mhrezaei/HighAvailabilitySetup/issues). Include detailed information like error messages, steps to reproduce, and screenshots if possible.

## Contributing
Contributions to improve or extend the functionality of these scripts are welcome. Follow these steps:
1. Fork the repository.
2. Create a new branch for your changes.
3. Commit changes and push them to your branch.
4. Submit a pull request with a comprehensive description of modifications.

Visit the [GitHub repository](https://github.com/mhrezaei/HighAvailabilitySetup) for more information and updates.
