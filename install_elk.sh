#!/bin/bash

set -e

echo "========================================"
echo "       ELK Stack Installer"
echo " Elasticsearch + Kibana + Logstash"
echo "              + Filebeat"
echo "========================================"

# ----------------------------------------
# Root check
# ----------------------------------------

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Run this script with sudo."
    echo "Example: sudo ./install_elk.sh"
    exit 1
fi

# ----------------------------------------
# Variables
# ----------------------------------------

ELASTIC_REPO="https://artifacts.elastic.co/packages/9.x/apt"
KEYRING="/usr/share/keyrings/elasticsearch-keyring.gpg"

# ----------------------------------------
# Dependencies
# ----------------------------------------

echo
echo "[1/9] Installing dependencies..."

apt update

apt install -y \
    apt-transport-https \
    wget \
    gnupg \
    curl

# ----------------------------------------
# Elastic GPG key
# ----------------------------------------

echo
echo "[2/9] Adding Elastic GPG key..."

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
    gpg --dearmor --yes -o "$KEYRING"

# ----------------------------------------
# Elastic repository
# ----------------------------------------

echo
echo "[3/9] Adding Elastic repository..."

cat > /etc/apt/sources.list.d/elastic-9.x.list <<EOF
deb [signed-by=$KEYRING] $ELASTIC_REPO stable main
EOF

apt update

# ----------------------------------------
# Install ELK + Filebeat
# ----------------------------------------

echo
echo "[4/9] Installing Elasticsearch, Kibana, Logstash and Filebeat..."

apt install -y \
    elasticsearch \
    kibana \
    logstash \
    filebeat

# ----------------------------------------
# Elasticsearch
# ----------------------------------------

echo
echo "[5/9] Configuring Elasticsearch..."

cat > /etc/elasticsearch/elasticsearch.yml <<EOF
cluster.name: elk-lab
node.name: elk-node

path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

network.host: 0.0.0.0
http.port: 9200

discovery.type: single-node

xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
EOF

# Elasticsearch heap
cat > /etc/elasticsearch/jvm.options.d/heap.options <<EOF
-Xms1g
-Xmx1g
EOF

# ----------------------------------------
# Remove automatically generated SSL secrets
# ----------------------------------------

echo
echo "Cleaning automatically generated Elasticsearch SSL settings..."

KEYSTORE="/usr/share/elasticsearch/bin/elasticsearch-keystore"

for setting in \
    xpack.security.http.ssl.keystore.secure_password \
    xpack.security.http.ssl.truststore.secure_password \
    xpack.security.transport.ssl.keystore.secure_password \
    xpack.security.transport.ssl.truststore.secure_password
do
    "$KEYSTORE" remove "$setting" 2>/dev/null || true
done

# ----------------------------------------
# Start Elasticsearch
# ----------------------------------------

echo
echo "Starting Elasticsearch..."

systemctl daemon-reload
systemctl enable elasticsearch
systemctl restart elasticsearch

echo "Waiting for Elasticsearch..."

for i in {1..30}; do

    if curl -s http://127.0.0.1:9200 >/dev/null 2>&1; then
        echo "Elasticsearch is UP."
        break
    fi

    sleep 2

    if [ "$i" -eq 30 ]; then
        echo
        echo "ERROR: Elasticsearch failed to start."
        echo
        systemctl status elasticsearch --no-pager -l
        echo
        echo "Last Elasticsearch errors:"
        grep -Ei "ERROR|Exception|FATAL|Caused by" \
            /var/log/elasticsearch/elk-lab.log | tail -30 || true
        exit 1
    fi

done

# ----------------------------------------
# Kibana
# ----------------------------------------

echo
echo "[6/9] Configuring Kibana..."

cat > /etc/kibana/kibana.yml <<EOF
server.port: 5601
server.host: "0.0.0.0"

elasticsearch.hosts: ["http://127.0.0.1:9200"]

EOF

systemctl enable kibana
systemctl restart kibana

# ----------------------------------------
# Logstash
# ----------------------------------------

echo
echo "[7/9] Configuring Logstash..."

mkdir -p /etc/logstash/conf.d

cat > /etc/logstash/conf.d/01-beats.conf <<EOF
input {
    beats {
        port => 5044
    }
}

filter {
}

output {
    elasticsearch {
        hosts => ["http://127.0.0.1:9200"]
        index => "filebeat-%{+YYYY.MM.dd}"
    }

    stdout {
        codec => rubydebug
    }
}
EOF

systemctl enable logstash
systemctl restart logstash

# ----------------------------------------
# Filebeat
# ----------------------------------------

echo
echo "[8/9] Configuring Filebeat..."

cat > /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:

- type: filestream
  id: ubuntu-system-logs
  enabled: true
  paths:
    - /var/log/*.log
    - /var/log/**/*.log

output.logstash:
  hosts: ["127.0.0.1:5044"]

logging.level: info
EOF

systemctl enable filebeat
systemctl restart filebeat

# ----------------------------------------
# Firewall
# ----------------------------------------

echo
echo "[9/9] Configuring firewall..."

if command -v ufw >/dev/null 2>&1; then

    ufw allow 5601/tcp
    ufw allow 5044/tcp

fi

# ----------------------------------------
# Final status
# ----------------------------------------

echo
echo "========================================"
echo "           INSTALLATION DONE"
echo "========================================"

echo
echo "Elasticsearch:"
systemctl is-active elasticsearch || true

echo "Kibana:"
systemctl is-active kibana || true

echo "Logstash:"
systemctl is-active logstash || true

echo "Filebeat:"
systemctl is-active filebeat || true

echo
echo "========================================"
echo "Endpoints"
echo "========================================"

echo
echo "Elasticsearch:"
echo "http://YOUR_SERVER_IP:9200"

echo
echo "Kibana:"
echo "http://YOUR_SERVER_IP:5601"

echo
echo "Logstash Beats:"
echo "YOUR_SERVER_IP:5044"

echo
echo "========================================"
echo "Elasticsearch test:"
echo "========================================"

curl -s http://127.0.0.1:9200

echo
echo
echo "========================================"
echo "ELK installation completed."
echo "========================================"