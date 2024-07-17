#!/bin/bash
sleep 3
# Define paths
BASE_DIR=~/NFCEmu
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
while :; do
echo "$(date): CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%, Mem: $(free -m | awk 'NR==2{printf "%.2f", $3*100/$2 }')" >> "$SYS_LOG"
sleep 5
done
}
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
# Start logging system usage
log_system_usage &
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
if is_process_running "$PYTHON_PROGRAM_PATH"; then
pkill -f "$PYTHON_PROGRAM_PATH"
echo "Existing Python program process killed."
fi
# Start the socket server (Qt based GUI using PyQt5)
echo "Starting socket server..."
# Change to GUI directory to ensure relative paths in the Python script work correctly
cd "$GUI_DIR"
# export DISPLAY=:0.0
python3 "$GUI_PATH" > "$PYTHON_LOG" 2>&1 &
# Wait for the socket server to be ready
echo "Waiting for the socket server to be ready..."
while ! is_socket_server_ready; do
sleep 1
done
echo "Socket server started."
# Start the Python program
echo "Starting Python program..."
python3 "$PYTHON_PROGRAM_PATH" > "$ANDROID_HCE_LOG" 2>&1 &
echo "All programs have been executed."