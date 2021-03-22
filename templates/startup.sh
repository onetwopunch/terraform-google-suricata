#!/bin/bash
add-apt-repository ppa:oisf/suricata-stable -y
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
bash add-logging-agent-repo.sh

# Install packages
apt update -y && apt -y install suricata apache2 google-fluentd

# Custom Rules
if [ "${custom_rules_path}" != "" ]; then 
  gsutil cp ${custom_rules_path} ${rule_file}
fi

# Suricata Conf
mv /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
cat <<"EOF" > /etc/suricata/suricata.yaml
${suricata_config}
EOF
systemctl restart suricata

# Cloud Logging
mkdir -p /etc/google-fluentd/config.d
cat <<"EOF" > /etc/google-fluentd/config.d/suricata.conf
${eve_config}
${fast_config}
EOF
systemctl restart google-fluentd

# Needs a simple HTTP server for health checks
echo "Suricata IDS - Packet Mirror" > /var/www/html/index.html
systemctl restart apache2


