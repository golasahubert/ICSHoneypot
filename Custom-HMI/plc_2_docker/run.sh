#!/bin/bash

SQL_SCRIPT="INSERT INTO Programs (Name, Description, File, Date_upload) VALUES ('PLC2', 'Descrizione', 'PLC2.st', strftime('%s', 'now'));"
#SQL_DEVICE="INSERT INTO Slave_dev (dev_name, dev_type, slave_id, ip_address, ip_port, di_start, di_size, coil_start, coil_size, ir_start, ir_size, hr_read_start, hr_read_size, hr_write_start, hr_write_size) VALUES ('Testdevice', 'TCP', 15, '127.0.0.1', 502, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);"
SQL_AUTOST="UPDATE Settings SET Value = 'true' WHERE Key = 'Start_run_mode';"

FILE=/home/OpenPLC_v3/started.txt

# openplc initialization
if ! [[ -f "$FILE" ]]; then

    sqlite3 /home/OpenPLC_v3/webserver/openplc.db "$SQL_AUTOST"
    
    # in order to make only one initialization
    echo "Don't remove this file" >> /home/OpenPLC_v3/started.txt
    
    # copying plc's ladder logic file and query execution
    cp /home/OpenPLC_v3/scripts/PLC2.st /home/OpenPLC_v3/webserver/st_files
    cp /home/OpenPLC_v3/scripts/PLC2.st.dbg /home/OpenPLC_v3/webserver/st_files
    sqlite3 /home/OpenPLC_v3/webserver/openplc.db "$SQL_SCRIPT"

    # setting st file and hardware driver
    sudo rm /home/OpenPLC_v3/webserver/active_program
    sudo rm /home/OpenPLC_v3/webserver/scripts/openplc_driver
    echo PLC2.st >> /home/OpenPLC_v3/webserver/active_program
    echo psm_linux >> /home/OpenPLC_v3/webserver/scripts/openplc_driver
    
fi 

# starting broker for plc's communication
sudo /home/OpenPLC_v3/.venv/bin/python3 /home/OpenPLC_v3/comm_modbus.py &

# starting lighttpd
nohup lighttpd -D -f /etc/lighttpd/lighttpd.conf &> httpd.log &

# starting snap7 server
sudo /home/honeyplc/snap7/examples/cpp/x86_64-linux/server 0.0.0.0 &

# starting OpenPLC
sudo /home/OpenPLC_v3/start_openplc.sh &

tail -f /dev/null
