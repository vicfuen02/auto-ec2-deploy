#!/bin/bash
set -x
dnf install -y java-25-amazon-corretto-headless

cat > /etc/systemd/system/app.service <<UNIT
[Unit]
Description=Spring Boot app
After=network.target

[Service]
ExecStartPre=/bin/bash -c 'until aws s3 cp s3://${artifacts_bucket}/app/app.jar /opt/app.jar; do sleep 10; done'
ExecStart=/usr/bin/java -jar /opt/app.jar --server.port=${app_port}
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now app
