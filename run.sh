#!/bin/bash

export DISPLAY=:0
xhost +local:pi # This gives the 'pi' user access to the X server
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=/home/pi/.Xauthority
# Log the environment
echo "Environment:"
env

# Define paths
BASE_DIR=/home/pi/NFCEmu
GUI_DIR="${BASE_DIR}/NFC-TerminalGUI-main/NFCD_GUI"
GUI_PATH="${GUI_DIR}/ui_cutie.py"
PYTHON_PROGRAM_PATH="${BASE_DIR}/NFCEmulator-1-main/Firmware/RPi_AndroidHCE/android_hce.py"
LOG_DIR="${BASE_DIR}/logs"
PYTHON_LOG="${LOG_DIR}/python_gui.log"
ANDROID_HCE_LOG="${LOG_DIR}/android_hce.log"
SYS_LOG="${LOG_DIR}/system_usage.log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Function to log system usage
log_system_usage() {
    echo "Logging system usage..."
    while true; do
        echo "$(date): CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%, Mem: $(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')" >>"$SYS_LOG"
        sleep 5
    done
}

# Function to check if a process is running
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null
    return $?
}

# Function to check if the socket server is listening on the expected port
is_socket_server_ready() {
    timeout 1 bash -c "echo > /dev/tcp/localhost/9999" 2>/dev/null
    return $?
}

# Function to check if a port is in use
is_port_in_use() {
    local port="$1"
    lsof -i :"$port" >/dev/null 2>&1
    return $?
}

# Function to gracefully kill the process using a specific port
graceful_kill_process_using_port() {
    local port="$1"
    local pid
    pid=$(lsof -ti :"$port")
    if [ -n "$pid" ]; then
        echo "Requesting the process using port $port to close :: (PID: $pid)..."
        kill "$pid"
        echo "$pid" # return the process id
    fi
}

# Function to wait for the process to be terminated otherwise kill it forcefully
wait_for_process_termination() {
    local pid="$1"
    local timeout_seconds=10
    local wait_interval=1
    for ((i = timeout_seconds; i > 0; i -= wait_interval)); do
        echo "Waiting for the process to close otherwise killing it in $i..."
        if ! kill -0 "$pid" 2>/dev/null; then
            echo "Process (PID: $pid) terminated successfully."
            return 0
        fi
        sleep "$wait_interval"
    done
    echo "Timeout reached. Forcefully killing process (PID: $pid)..."
    kill -9 "$pid" 2>/dev/null
}
# Function to gracefully kill a process by PID
graceful_kill() {
    local pid="$1"
    if [ -n "$pid" ]; then
        echo "Requesting the process (PID: $pid) to close..."
        kill "$pid"
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            echo "Timeout reached. Forcefully killing process (PID: $pid)..."
            kill -9 "$pid" 2>/dev/null
        else
            echo "Process (PID: $pid) terminated successfully."
        fi
    fi
}
# Start the socket server (Qt based GUI using PyQt5)
start_gui() {
    cd "$GUI_DIR"
    DISPLAY=:0 python3 "$GUI_PATH" >"$PYTHON_LOG" 2>&1 &
    GUI_PID=$!
    echo "Socket server started with PID: $GUI_PID"
}

# Start the Python program
start_python_program() {
    cd "$(dirname "$PYTHON_PROGRAM_PATH")"
    python3 "$PYTHON_PROGRAM_PATH" >"$ANDROID_HCE_LOG" 2>&1 &
    PYTHON_PID=$!
    echo "Python program started with PID: $PYTHON_PID"
}

# Start logging system usage
log_system_usage &

# Main loop
while true; do

    # Start the socket server if it's not running
    if ! is_process_running "$GUI_PATH"; then
        start_gui
    fi

    # Wait for the socket server to be ready
    echo "Waiting for the socket server to be ready..."
    timeout=60
    while ! is_socket_server_ready; do
        sleep 0.5
        timeout=$((timeout - 1))
        if [ $timeout -le 0 ]; then
            echo "Timeout waiting for socket server. Restarting..."
            # kill $GUI_PID
            continue 2 # Continue the outer loop
        fi
    done

    # Start the Python program if it's not running
    if ! is_process_running "$PYTHON_PROGRAM_PATH"; then
        start_python_program
    fi

    echo "Socket server started."

    echo "All programs have been executed."

    # Wait for either process to exit
    wait -n $GUI_PID $PYTHON_PID

    # Check which process exited and restart it
    # if ! kill -0 $GUI_PID 2>/dev/null; then
    #     echo "Socket server (PID: $GUI_PID) exited. Restarting..."
    #     start_gui
    # fi
    # if ! kill -0 $PYTHON_PID 2>/dev/null; then
    #     echo "Python program (PID: $PYTHON_PID) exited. Restarting..."
    #     start_python_program
    # fi
    sleep 0.5
done
