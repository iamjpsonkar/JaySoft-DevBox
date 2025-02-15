#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    set -a; . .env; set +a
fi

# Ensure necessary directories exist
mkdir -p ./prometheus ./grafana/provisioning/datasources \
            ./grafana/provisioning/dashboards ./mysql_exporter \
            ./kafka_ui ./zookeeper ./redis ./postgres

# Generate prometheus.yml if enabled
if [ "${BUILD_PROMETHEUS-0}" -eq 1 ]; then
    PROMETHEUS_CONF="./prometheus/prometheus.yml"
    echo "Generating Prometheus configuration..."
    
    cat > "$PROMETHEUS_CONF" <<EOL
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:${PROMETHEUS_PORT-9090}']
EOL

    # Add exporters if enabled
    if [ "${BUILD_KAFKA_EXPORTER-0}" -eq 1 ] || 
       [ "${BUILD_MYSQL_EXPORTER-0}" -eq 1 ] ||
       [ "${BUILD_POSTGRES_EXPORTER-0}" -eq 1 ] ||
       [ "${BUILD_REDIS_EXPORTER-0}" -eq 1 ]; then
        cat >> "$PROMETHEUS_CONF" <<EOL
  - job_name: 'docker_services'
    static_configs:
      - targets:
EOL

        [ "${BUILD_KAFKA_EXPORTER-0}" -eq 1 ] && echo "        - 'kafka_exporter:${KAFKA_EXPORTER_PORT-9308}'" >> "$PROMETHEUS_CONF"
        [ "${BUILD_MYSQL_EXPORTER-0}" -eq 1 ] && echo "        - 'mysql_exporter:${MYSQL_EXPORTER_PORT-9104}'" >> "$PROMETHEUS_CONF"
        [ "${BUILD_POSTGRES_EXPORTER-0}" -eq 1 ] && echo "        - 'postgres_exporter:${POSTGRES_EXPORTER_PORT-9187}'" >> "$PROMETHEUS_CONF"
        [ "${BUILD_REDIS_EXPORTER-0}" -eq 1 ] && echo "        - 'redis_exporter:${REDIS_EXPORTER_PORT-9121}'" >> "$PROMETHEUS_CONF"

        cat >> "$PROMETHEUS_CONF" <<EOL
    relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):(\d+)'
        replacement: 'localhost:\${2}'
        target_label: instance
EOL
    fi

    echo "✅ prometheus.yml generated at $PROMETHEUS_CONF"
fi

# Generate Grafana configurations if enabled
if [ "${BUILD_GRAFANA-0}" -eq 1 ]; then
    echo "Generating Grafana configurations..."
    
    # Datasources
    GRAFANA_DATASOURCES="./grafana/provisioning/datasources/datasources.yml"
    cat > "$GRAFANA_DATASOURCES" <<EOL
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:${PROMETHEUS_PORT-9090}
    access: proxy
    isDefault: true
EOL
    echo "✅ Grafana datasources.yml generated"

    # Dashboards
    GRAFANA_DASHBOARDS="./grafana/provisioning/dashboards/dashboards.yml"
    cat > "$GRAFANA_DASHBOARDS" <<EOL
apiVersion: 1
providers:
  - name: "default"
    orgId: 1
    folder: ""
    type: "file"
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
EOL
    echo "✅ Grafana dashboards.yml generated"
fi

# Generate MySQL .my.cnf if enabled
if [ "${BUILD_MYSQL-0}" -eq 1 ]; then
    echo "Generating MySQL configuration..."
    mkdir -p "./mysql_exporter"
    chmod 700 "./mysql_exporter"
    cat > "./mysql_exporter/.my.cnf" <<EOF
[client]
user=${MYSQL_USER:-root}
password=${MYSQL_PASS:-root}
host=${MYSQL_HOST-mysql}
port=${MYSQL_PORT-3306}
EOF
    chmod 600 "./mysql_exporter/.my.cnf"
    echo "✅ MySQL credentials generated"
fi

# Generate Kafka UI config if enabled
if [ "${BUILD_KAFKA_UI-0}" -eq 1 ]; then
    echo "Generating Kafka UI configuration..."
    cat > "./kafka_ui/application.yml" <<EOL
kafka:
  clusters:
    - name: local
      bootstrapServers: kafka:${KAFKA_PORT-9092}
      zookeeper: zookeeper:${ZOOKEEPER_PORT-2181}
EOL
    echo "✅ Kafka UI configuration generated"
fi

echo "✅ All configurations generated successfully"
