# ELK Stack Installation Script

Bash script for installing and configuring the **ELK Stack** on Ubuntu.

## Components

* Elasticsearch
* Logstash
* Kibana
* Filebeat

## Features

* Automated installation
* Basic service configuration
* Elasticsearch single-node setup
* Kibana configuration
* Logstash Beats input configuration
* Filebeat configuration
* Required firewall rules

## Usage

```bash
chmod +x install-elk.sh
sudo ./install-elk.sh
```

After installation:

* Elasticsearch: `:9200`
* Kibana: `:5601`
* Logstash Beats input: `:5044`

Built for quickly deploying ELK lab environment.

