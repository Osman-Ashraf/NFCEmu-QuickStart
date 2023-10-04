#!/bin/bash

# Define paths
BASE_DIR=~/NFCEmu
GUI_DIR="${BASE_DIR}/NFC-TerminalGUI-main/NFCD_GUI"
GUI_PATH="${GUI_DIR}/tk_ui.py"
CPP_PROGRAM_PATH="${BASE_DIR}/NFCEmulator-main/Firmware/RPi_AndroidHCE/android_hce"

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

# Kill existing processes if they are running
if is_process_running "$GUI_PATH"; then
    pkill -f "$GUI_PATH"
    echo "Existing Python GUI process killed."
fi

if is_process_running "$CPP_PROGRAM_PATH"; then
    pkill -f "$CPP_PROGRAM_PATH"
    echo "Existing C++ program process killed."
fi

# Start the socket server (Python3 based tkinter GUI)
echo "Starting socket server..."

# Change to GUI directory to ensure relative paths in the Python script work correctly
cd "$GUI_DIR"
DISPLAY=:0 python3 "$GUI_PATH" &

# Wait for the socket server to be ready
echo "Waiting for the socket server to be ready..."
while ! is_socket_server_ready; do
    sleep 1
done
echo "Socket server started."

# Start the C++ program
echo "Starting C++ program..."
"$CPP_PROGRAM_PATH"

echo "All programs have been executed."
