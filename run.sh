#!/bin/bash

sleep 3

# Define paths
BASE_DIR=~/NFCEmu
GUI_DIR="${BASE_DIR}/NFC-TerminalGUI-main/NFCD_GUI"
GUI_PATH="${GUI_DIR}/ui_cutie.py"
# PIR_PATH="${GUI_DIR}/pir.py"
CPP_PROGRAM_PATH="${BASE_DIR}/NFCEmulator-1-main/Firmware/RPi_AndroidHCE/android_hce"

# Function to check if a process is running
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" > /dev/null
    return $?
}

# Function to check if the socket server is listening on the expected port (assuming port 9999)
is_socket_server_ready() {
    netstat -tuln | grep -q ":9999 "
    return $?
}

# Function to check if a port is in use
is_port_in_use() {
    local port="$1"
    lsof -i :"$port" > /dev/null 2>&1
    return $?
}

# Function to gracefully kill the process using a specific port
graceful_kill_process_using_port() {
    local port="$1"
    local pid
    pid=$(lsof -i :"$port" -t)
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
        if ! ps -p "$pid" > /dev/null; then
            echo "Process (PID: $pid) terminated successfully."
            return 0
        fi
        sleep "$wait_interval"
    done

    echo "Timeout reached. Forcefully killing process (PID: $pid)..."
    kill -9 "$pid"
}

# Check and make the desired port available
if is_port_in_use 9999; then
    echo "Port 9999 is already in use."
    # Request the process to cleanup and close
    pid=$(graceful_kill_process_using_port 9999)
    # Wait for the process to cleanup and close
    if [ -n "$pid" ]; then
        wait_for_process_termination "$pid"
    fi
fi

# Kill existing processes if they are running
if is_process_running "$GUI_PATH"; then
    pkill -f "$GUI_PATH"
    echo "Existing Python GUI process killed."
fi

if is_process_running "$CPP_PROGRAM_PATH"; then
    pkill -f "$CPP_PROGRAM_PATH"
    echo "Existing C++ program process killed."
fi

# Start the socket server (Qt based GUI using PyQt5)
echo "Starting socket server..."

# Change to GUI directory to ensure relative paths in the Python script work correctly
cd "$GUI_DIR"

# export DISPLAY=:0.0
python3 "$GUI_PATH" &
# python3 "$PIR_PATH" &

# Wait for the socket server to be ready
echo "Waiting for the socket server to be ready..."
while ! is_socket_server_ready; do
    sleep 1
done
echo "Socket server started."

# Start the C++ program
echo "Starting C++ program..."
"$CPP_PROGRAM_PATH" &

echo "All programs have been executed."
