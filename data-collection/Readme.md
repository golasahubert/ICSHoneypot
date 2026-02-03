# File for monitoring

- capture.sh : is the file used to start the tcpdump on the network interface, filtering for our IP addresses
- capture.service : this file is used to have the file capture.sh continuously running even after a restart of the machine. This file must be copied in the ``/etc/systemd/system/`` directory, then enabled by these commands ``systemctl daemon-reload`` and ``systemctl enable capture.service``. Finally, run it with ``systemctl start capture.service``.
- clean.sh : this file is used to remove the file older then seven days. To have this file running can be used a cronjob like ``0 3 * * * /path/to/file`` or ``@daily /path/to/file`
- logCollector.sh: this file is used to collect all the log file of all the VPS in a single machine. This file need to: 
  - have an ssh connection key enable for each of the VPS in order to connect and copy the file
  - rsync installed 
  - write the VPS information in the array like the example in the file
  Then for have this file run automatically setup a cronjob like ``@daily /path/to/file >> /path/to/optional/log/file`` in order to sync all the files incrementally.
