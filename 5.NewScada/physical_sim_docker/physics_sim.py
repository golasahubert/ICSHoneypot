'''
A program that:
- Creates network sockets for each UDP server associated with the PSM interfaces, which represent 
the individual PLCs involved in the system;
- Receives data from the UDP servers of the PSM interfaces that provides information about 
the current status of the actuators;
- Updates the simulated physical system based on the previous state of the system and the 
newly received actuator data;
- Transmits data about the updated system state to the UDP servers of the SMP interfaces.
'''

import socket
from time import sleep
import numpy as np
from scipy.integrate import odeint
import matplotlib.pyplot as plt
import pickle as pkl # array serialization/deserialization module for byte stream
import json

# communication info
udp_servers_info = [] # array which contains the network info about PSM interfaces UDP servers (ip addr and port)
udp_clients = [] #  array which contains clients UDP sockets for the communication with PSM servers

# plcs info
actuator_states = [] # array of arrays, which contains actuator states of each PLC
sensor_states = [] # array of arrays, which contains sensor states of each PLC

# sim info
simulated_data = np.array([]) # numpy array, which contains simulation datas
delta_t = 1 # default delta simulation time
t = np.array([0,delta_t]) # simulation pass
x0 = () # system inital state

# plotting info
sec = 0
time = [0]
sensor_states_plt = []

def initialization_variables():
    '''Function to initialize variables'''
    global udp_servers_info
    global actuator_states
    global sensor_states
    global simulated_data
    global delta_t
    global sensor_states_plt
    global x0

    try:
        config_file = open("/home/config.json") # /home/mattia/Desktop/MAGISTRALE/TESI/CASE_STUDY_PROJECTS/VRSWaT_case_study/without_matlab/physical_sim_docker/
    except Exception as error:
        print(error)

    try:
        config_data = json.load(config_file)
    except Exception as error:
        print(error)

    # initializing PSM interface servers info
    for plc in list(config_data["plcs"].keys()):
        udp_servers_info.append((config_data["plcs"][plc]["ip"],config_data["plcs"][plc]["port"]))
    
    # initializing actuator and sensor arrays
    # NB The actuator_states and sensor_states arrays will contain repectively the actuators and sensor
    # of each plc in the order of apparence
    # ex. if plc1 has two actuators and plc2 has one actuators the actuator_states array will be [[0,0],[0]],
    # where each sub array contains the actuators of the plc!!!
    for plc in list(config_data["plcs"].keys()):

        input_regs = []
        output_regs = []

        for input_reg in list(config_data["plcs"][plc]["registers"]["input_regs"].keys()):
            input_regs.append(config_data["plcs"][plc]["registers"]["input_regs"][input_reg])
        
        for output_reg in list(config_data["plcs"][plc]["registers"]["output_regs"].keys()):
            output_regs.append(config_data["plcs"][plc]["registers"]["output_regs"][output_reg])

        sensor_states.append(input_regs)
        actuator_states.append(output_regs)

    # initializing system initial state array
    initial_state = []
    for plc_regs_states in sensor_states:
        # to manage the case where a PLC has more than one sensor
        for plc_reg_state in plc_regs_states:
            initial_state.append(plc_reg_state)
            
    simulated_data = np.array(initial_state)
    x0 = tuple(initial_state)

    # initializing delta simulation time
    delta_t = config_data["physic_sim"]["delta_t"]

    # initializing plotting array
    i = 0
    for plc_regs_states in sensor_states:
        sensor_states_plt.append([])
        for plc_reg_state in plc_regs_states:
            sensor_states_plt[i].append([plc_reg_state])
        i += 1

def create_sockets_UDP():
    '''Function to create UDP sockets for transmitting and receiving data with PSM interfaces UDP servers'''
    global udp_servers_info
    global udp_clients

    # client sockets creation for each PSM servers 
    for _ in range(len(udp_servers_info)):

        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM) # UDP
            sock.setblocking(False)
            udp_clients.append(sock)
        except Exception as error:
            pass

def update_variables():
    '''Function to receive PLCs variables values from PSM interfaces UDP servers'''
    global udp_clients
    global actuator_states

    # Receiving datas from UDP servers
    for i in range(len(actuator_states)):

        if(len(actuator_states[i]) != 0): # to manage the case where a PLC doesn't control any actuator

            try:
                old_value = actuator_states[i]
                received_data = udp_clients[i].recv(1024)
                actuator_states[i] = pkl.loads(received_data) # deserialization of received data from the server
            except Exception as error:
                actuator_states[i] = old_value
                pass

    return 0

def send_level_values_to_servers():
    '''Function to send simulated values to PSM interfaces UDP servers'''
    global simulated_data
    global udp_clients
    global udp_servers_info
    global sensor_states

    pointer = 0 # to scroll simulated_data array
    for i in range(len(sensor_states)):
        
        if(len(sensor_states[i]) != 0): # to catch the case where a PLC doesn't have any sensor
            data = [] # data to send
            for j in range(len(sensor_states[i])):
                value = '%.5f'%float(simulated_data[pointer]) # data cleaning
                sensor_states[i][j] = value
                data.append(value)
                pointer += 1

            # sending sensor values to UDP server
            serialized_data = pkl.dumps(data)
            try:
                udp_clients[i].sendto(serialized_data, udp_servers_info[i])
            except Exception as error:
                print("Sending error")
                pass

    return 0 

####################################################################################
# Function which should be modified with the desired differential equations system # 
# Where:                                                                           #
# - x is a tuple which contains the actual state (ex. lever of tanks h1,h2,h3)     #
# - t is a numpy array which contains simulation times                             #
# - the returned tuple contains singles first order differential equations!!!      #
def mydiff(x,t):
    '''Function which return the differential equations system'''
    global actuator_states

    area_base_tank_1 = 100 # base area of tank_1 (cm^2)
    area_base_tank_2 = 100 # base area of tank_2 (cm^2)
    area_base_tank_3 = 100 # base area of tank_3 (cm^2)
    throughput_pump_1 = 100 # pump_1's throughput (cm^3/s)
    throughput_pump_2 = 100 # pump_2's throughput (cm^3/s)
    area_pipe_1 = 0.45 # Area of the pipe which connect tank_1 and tank_2 (cm^2)
    const_pipe_1 = 0.5
    area_pipe_2 = 0.25 # Area of the pipe which connect tank_2 and tank_3 (cm^2)
    const_pipe_2 = 0.5
    dirty_water_prob = 0.1 # Probability linked to the quantity of water entering tank_3
    g = 980.665 # grav const (cm/s^2)

    # actuator variables (the programmer have to know the mapping between actuator_states array elements and the real actuator!!!)
    pump_1 = actuator_states[0][0]
    pump_2 = actuator_states[2][0]
    valve_1 = actuator_states[0][1]

    q_in = (throughput_pump_1) # entry flow tank_1
    alpha_1_2 = area_pipe_1 * const_pipe_1
    q_1_2 = alpha_1_2 * ((2*g*x[0])**(1/2)) # flow between tank_1 and tank_2
    alpha_2_3 = area_pipe_2 * const_pipe_2
    q_2_3 = alpha_2_3 * ((2*g*x[1])**(1/2)) # flow between tank_2 and tank_3
    q_3_2 = (throughput_pump_2) # flow between tank_3 and tank_2

    # ODE system with three first order differental equations
    dxdt_1 = (pump_1*q_in - valve_1*q_1_2)/area_base_tank_1
    dxdt_2 = (valve_1*q_1_2 + pump_2*q_3_2 - q_2_3)/area_base_tank_2
    dxdt_3 = (dirty_water_prob*q_2_3 - pump_2*q_3_2)/area_base_tank_3

    return (dxdt_1,dxdt_2,dxdt_3)
########################################################################################

if __name__ == "__main__":
    
    sleep(5) # Waiting docker containers initialization
    initialization_variables()
    create_sockets_UDP()

    while True:

        send_level_values_to_servers()
        sleep(delta_t) # to keep simulation time consistent and scan cycle coordination
        update_variables()
        print("sensors: " + str(sensor_states))
        print("actuators: " + str(actuator_states) + "\n")
        

        # realize a simulation pass
        [ old_state, simulated_data ] = odeint(mydiff, x0,t)

        #####################################################################
        # Simulated data correction                                         #
        # NB These constraints could be incorporated into the ODE system!!! #
        max_capacities = np.array([100,30,4]) # max capacity of tank1, tank2 and tank3
        for i in range(len(simulated_data)):
            # check upper bound
            if simulated_data[i] > max_capacities[i]:
                simulated_data[i] = max_capacities[i]
            # check lower bound
            if simulated_data[i] < 0:
                simulated_data[i] = 0
        ####################################################################

        # update actual system state
        x0 = simulated_data

        '''
        # real-time plot
        time.append(sec)
        pointer = 0
        for i in range(len(sensor_states_plt)):
            for j in range(len(sensor_states_plt[i])):
                sensor_states_plt[i][j].append(float(simulated_data[pointer]))
                pointer += 1

        plt.cla()
        for i in range(len(sensor_states_plt)):
            for j in range(len(sensor_states_plt[i])):
                plt.plot(time, sensor_states_plt[i][j],label='tank ' + str(i+1) + ' level')
        plt.legend()
        plt.pause(delta_t) # to keep simulation time consistent
        sec += 1'''