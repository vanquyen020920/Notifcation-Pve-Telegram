Step1:
nano /usr/local/bin/backup-notify.sh
Step2:
chmod +x /usr/local/bin/backup-notify.sh
Step3:
sudo nano /etc/systemd/system/backup-notify.service
[Unit]
Description=Proxmox Backup Notification Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/backup-notify.sh
Restart=always
User=root
WorkingDirectory=/usr/local/bin
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target



Step4:
systemctl daemon-reload
systemctl enable backup-notify.service
systemctl start backup-notify.service
systemctl status backup-notify.service
