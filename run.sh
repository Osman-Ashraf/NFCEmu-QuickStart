#!/bin/bash

# Define paths
BASE_DIR=~/NFCEmu
GUI_PATH="${BASE_DIR}/NFC-TerminalGUI-main/NFCD_GUI/tk_ui.py"
CPP_PROGRAM_PATH="${BASE_DIR}/NFCEmulator-main/Firmware/RPi_AndroidHCE/android_hce"

# Function to check if a process is running
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" > /dev/null
    return $?
}

# Start the socket server (Python3 based tkinter GUI)
echo "Starting socket server..."
DISPLAY=:0 python3 "$GUI_PATH" &

# Wait for the socket server to start
while ! is_process_running "$GUI_PATH"; do
    sleep 1
done
echo "Socket server started."

# Start the C++ program
echo "Starting C++ program..."
"$CPP_PROGRAM_PATH"

echo "All programs have been executed."
