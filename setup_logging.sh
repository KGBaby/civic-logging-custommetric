#!/bin/bash

# Ensure the API key is provided
if [ -z "$DATADOG_API_KEY" ]; then
  echo "Error: DATADOG_API_KEY environment variable is not set."
  exit 1
fi

# Step 1: Create the Python Script
sudo bash -c 'cat << EOF > /usr/local/bin/generate_log.py
import json
from datetime import datetime
import random
import time

def generate_random_ip():
    """Select a random public IP address from a predefined list."""
    ip_list = [
        "151.101.1.69", "104.244.42.1", "172.217.16.1", "151.101.65.69", "104.244.42.2",
        "172.217.17.1", "151.101.129.69", "104.244.42.3", "172.217.18.1", "151.101.193.69",
        "104.244.42.4", "172.217.19.1", "151.101.1.70", "104.244.42.5", "172.217.20.1",
        "151.101.65.70", "104.244.42.6", "172.217.21.1", "151.101.129.70", "104.244.42.7",
        "172.217.22.1", "151.101.193.70", "104.244.42.8", "172.217.23.1", "151.101.1.71"
    ]
    return random.choice(ip_list)

def generate_log_entry():
    """Generate a single JSON log entry."""
    log_entry = {
        "Timestamp": datetime.now().isoformat(),
        "Message": "Sample log message",
        "UserID": random.randint(1000, 9999),
        "ErrorCode": random.randint(1, 100),
        "levelname": random.choice(["ERROR", "INFO"]),
        "Network": {
            "Client": {
                "IP": generate_random_ip()
            }
        }
    }
    return log_entry

def continuously_generate_json_log():
    """Continuously generate and append JSON log entries to a file."""
    file_path = "/var/log/continuous_json_log.json"
    while True:
        entry = generate_log_entry()
        with open(file_path, "a") as file:
            file.write(json.dumps(entry) + "\n")
        time.sleep(1)  # Pause for 1 second before the next log entry

# Run the continuous log generation
continuously_generate_json_log()
EOF'

# Make the Python script executable
sudo chmod +x /usr/local/bin/generate_log.py

# Step 2: Create a Systemd Service
sudo bash -c 'cat << EOF > /etc/systemd/system/generate_log.service
[Unit]
Description=Generate JSON Logs Continuously

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/generate_log.py
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF'

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable generate_log.service
sudo systemctl start generate_log.service

# Step 3: Install Datadog Agent
DD_AGENT_MAJOR_VERSION=7 DD_API_KEY=$DATADOG_API_KEY DD_SITE="datadoghq.com" bash -c "$(curl -L https://s3.amazonaws.com/dd-agent/scripts/install_script.sh)"

# Step 4: Configure Datadog Agent to Monitor the Log File
sudo mkdir -p /etc/datadog-agent/conf.d/custom_log.d
sudo bash -c 'cat << EOF > /etc/datadog-agent/conf.d/custom_log.d/conf.yaml
logs:
  - type: file
    path: /var/log/continuous_json_log.json
    service: custom_service
    source: python
EOF'

# Ensure Datadog Agent log collection is enabled
sudo sed -i 's/^# logs_enabled: false/logs_enabled: true/' /etc/datadog-agent/datadog.yaml

# Restart Datadog Agent to apply changes
sudo systemctl restart datadog-agent

# Step 5: Create Custom Metrics Directory and Configuration File
sudo mkdir -p /etc/datadog-agent/conf.d/metrics_example.d

# Create the metrics_example.yaml configuration file
sudo bash -c 'cat << EOF > /etc/datadog-agent/conf.d/metrics_example.d/conf.yaml
instances: [{}]
EOF'

# Step 6: Create Custom Check Script for Custom Metrics
sudo bash -c 'cat << EOF > /etc/datadog-agent/checks.d/metrics_example.py
import random
from datadog_checks.base import AgentCheck

__version__ = "1.0.0"

class MetricsExampleCheck(AgentCheck):
    def generate_random_owner(self):
        owners = ["Alice", "Bob", "Charlie", "Dave", "Eve"]
        return random.choice(owners)
    
    def generate_random_host(self):
        hosts = ["server1", "server2", "server3", "server4", "server5"]
        return random.choice(hosts)
    
    def generate_random_availability_zone(self):
        zones = ["us-east-1a", "us-east-1b", "us-west-1a", "us-west-1b"]
        return random.choice(zones)
    
    def generate_random_account(self):
        accounts = ["account123", "account456", "account789", "account012"]
        return random.choice(accounts)
    
    def check(self, instance):
        metric_names = [
            "system.cpu.value", "system.memory.usage", "system.disk.read",
            "system.disk.write", "system.network.in", "system.network.out",
            "system.load.1", "system.load.5", "system.load.15",
            "system.uptime", "system.swap.usage", "system.swap.free",
            "system.disk.inode_usage", "application.latency",
            "application.requests", "application.errors", "application.threads",
            "application.connections", "service.advertisements.latency",
            "service.advertisements.requests", "service.advertisements.errors",
            "service.frontend.latency", "service.frontend.requests",
            "service.frontend.errors", "service.my_service.latency",
            "service.my_service.requests", "service.my_service.errors",
            "database.queries.count", "database.queries.errors",
            "database.connections.active", "database.connections.idle",
            "database.connections.waiting", "cache.hits", "cache.misses",
            "cache.evictions", "cache.used_memory", "cache.total_memory",
            "queue.jobs.enqueued", "queue.jobs.processed", "queue.jobs.failed",
            "queue.jobs.retries"
        ]
        
        high_frequency_metrics = [
            "system.cpu.value", "system.memory.usage", "system.disk.read",
            "system.disk.write", "system.network.in", "system.network.out",
            "system.load.1", "system.load.5", "system.load.15", "system.uptime"
        ]
        
        tags = [
            "env:dev",
            f"host:{self.generate_random_host()}",
            f"owner:{self.generate_random_owner()}",
            f"availability_zone:{self.generate_random_availability_zone()}",
            "location:datacenter1",
            f"account:{self.generate_random_account()}"
        ]
        
        for metric in metric_names:
            self.gauge(
                metric,
                random.randint(0, 100),
                tags=tags,
            )
        
        for metric in high_frequency_metrics:
            for _ in range(10):  # Send 10 times more data points for these metrics
                self.gauge(
                    metric,
                    random.randint(0, 100),
                    tags=tags,
                )
            
        # Example of histogram metrics
        self.histogram(
            "service.my_service.latency.histogram",
            random.randint(0, 100),
            tags=tags,
        )
        self.histogram(
            "service.my_service.latency.histogram",
            random.randint(0, 100),
            tags=tags,
        )

        # Example of rate metrics
        self.rate(
            "system.network.packets",
            random.randint(0, 100),
            tags=tags,
        )
EOF'

# Ensure the Datadog Agent checks directory is owned by the correct user
sudo chown -R dd-agent:dd-agent /etc/datadog-agent/checks.d/

# Restart Datadog Agent to apply custom check
sudo systemctl restart datadog-agent

# Verify Datadog Agent status
sudo systemctl status datadog-agent

echo "Setup complete. Custom metrics are being sent to Datadog."
