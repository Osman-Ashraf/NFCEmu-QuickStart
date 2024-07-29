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
VENV_DIR="$GUI_DIR/venv"
GUI_PATH="${GUI_DIR}/ui_cutie.py"
LOG_DIR="${BASE_DIR}/logs"
PYTHON_LOG="${LOG_DIR}/python_gui.log"
SYS_LOG="${LOG_DIR}/system_usage.log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Function to log system usage
log_system_usage() {
    echo "Logging system usage..."
    while true; do
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
        mem_usage=$(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')
        total_mem=$(free -m | awk 'NR==2{printf "%s", $2}')
        used_mem=$(free -m | awk 'NR==2{printf "%s", $3}')
        free_mem=$(free -m | awk 'NR==2{printf "%s", $4}')
        echo "$(date): CPU: ${cpu_usage}%, Mem: ${mem_usage}%, Total Mem: ${total_mem}MB, Used Mem: ${used_mem}MB, Free Mem: ${free_mem}MB" >>"$SYS_LOG"
        sleep 5
    done
}

# Function to check if a process is running
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null
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
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate" # Activate the virtual environment
        $VENV_DIR/bin/pip3 install -r requirements.txt
        # sudo apt install libxcb-cursor-dev
    fi
    source "$VENV_DIR/bin/activate" # Activate the virtual environment
    DISPLAY=:0 python3 "$GUI_PATH" >"$PYTHON_LOG" 2>&1 &
    GUI_PID=$!
    echo "Socket server started with PID: $GUI_PID"
}

# Start logging system usage
log_system_usage &

# Main loop
while true; do

    # Start the socket server if it's not running
    if ! is_process_running "$GUI_PATH"; then
        start_gui
    fi

    echo "All programs have been executed."

    # Wait for either process to exit
    wait -n $GUI_PID

    sleep 0.5
done
