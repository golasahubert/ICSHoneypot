import socket
import psm
from time import sleep
import pickle as pkl
import json
import modbus_tk.defines as cst
import modbus_tk.modbus_tcp as modbus_tcp

#inital state variables
plc_input_reg_addrs = [] # plc's input registers memory addresses
plc_output_reg_addrs = [] # plc's output registers memory addresses
server_UDP_info = ('',0) # interface server address and port
client_UDP_info = ('',0) # physic simulator client address and port
udp_server = None # Socket for UDP server
modbus_client = None # Socket for Modbus client

# To initialize variables
def initaialization_variables():
    global plc_input_reg_addrs
    global plc_output_reg_addrs
    global server_UDP_info
    
    plc_input_reg_addrs = []
    plc_output_reg_addrs = []
    server_UDP_info = ()
    
    #getting plc name
    try:
        file = open("/home/OpenPLC_v3/plc_name.txt")
    except Exception as error:
        print(error)

    try:
        plc_name = file.read()
    except Exception as error:
        print(error)

    # getting configuaration info
    try:
        config_file = open("/home/OpenPLC_v3/config.json")
    except Exception as error:
        print(error)

    try:
        config_data = json.load(config_file)
    except Exception as error:
        print(error)

    # getting plc input registers
    for input_reg in list(config_data["plcs"][plc_name]["registers"]["input_regs"].keys()):
        plc_input_reg_addrs.append(input_reg)
        
    # getting plc output registers
    for output_reg in list(config_data["plcs"][plc_name]["registers"]["output_regs"].keys()):
        plc_output_reg_addrs.append(output_reg)

    # getting PSM interface server ip and port
    server_UDP_info = (config_data["plcs"][plc_name]["ip"],config_data["plcs"][plc_name]["port"])

# To start interface UDP server
def starting_udp_server():
    global udp_server
    global server_UDP_info
    
    try:
        udp_server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        udp_server.bind(server_UDP_info)
        print("Server UDP up!!!")
    except socket.error as error:
        print("error during UDP server initialization!!!")

# To start Modbus client
def starting_modbus_client():
    global modbus_client

    sleep(5) # Waiting PLC initialization
    
    while True:
        try:
            # Connecting to plc
            modbus_client = modbus_tcp.TcpMaster('127.0.0.1', 502)
            modbus_client.set_timeout(5.0)
            print("Connection to Modbus server done!!!")
            break
        except:
            print("error during connectin to the plc!!!")

def hardware_init():
    
    psm.start()

    # initializing variables
    initaialization_variables()

    # starting the UDP server
    starting_udp_server()

    # starting the Modbus client
    starting_modbus_client()

# to update PLC's input registers, or any other PLC register
def get_input_from_sim():
    global plc_input_reg_addrs
    global udp_server
    global client_UDP_info
    
    # Getting datas from the physical simulator client
    [data,client_UDP_info]  = udp_server.recvfrom(4096)
    sensors_states = pkl.loads(data) # deserialization of received data from PSM interface
    
    print("sensors states: ")
    # updating the PLC's level varaible (registers)
    for i in range(len(sensors_states)):
        value = int(float(sensors_states[i]))
        psm.set_var(plc_input_reg_addrs[i], value) 
        print( plc_input_reg_addrs[i] + " : " + str(value))
        
# to update actuator states
def send_output_to_sim():
    global plc_output_reg_addrs
    global udp_server
    global client_UDP_info
    global modbus_client
    
    actuators_states = []
    print("actuators states: ")
    # reading values from PLC's registers
    for i,reg in enumerate(plc_output_reg_addrs):
        
        # Reading coils from main OpenPLC Modbus server
        try:
            value = modbus_client.execute(1, cst.READ_COILS, i, 1)
            actuators_states.append(value[0])
            print( reg + " : " + str(value[0]) )
        except:
            print("Reading error")
    
    print("\n")

    serializad_data = pkl.dumps(actuators_states) # data serialization
    # sending actauators states to the simulator client
    udp_server.sendto(serializad_data, client_UDP_info) 

if __name__ == "__main__":

    hardware_init()

    print(plc_input_reg_addrs)
    print(plc_output_reg_addrs)
    print(server_UDP_info)
    
    while (not psm.should_quit()):
        
        if len(plc_input_reg_addrs) != 0:
            get_input_from_sim() # to update PLC's input registers
            
        sleep(0.3) # To mantain consistency with the scan cycle

        if len(plc_output_reg_addrs) != 0:
            send_output_to_sim() # to update actuators values (sending these info to the simulator)

    psm.stop()
