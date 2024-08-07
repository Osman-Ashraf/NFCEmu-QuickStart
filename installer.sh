#!/bin/bash
# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf " \b\b\b\b"
}

# Check for internet connection
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    echo "No internet connection. Please check your connection and try again."
    exit 1
fi

# Check if TOKEN environment variable is set and not empty
if [[ -z "${TOKEN}" ]]; then
    echo "Please set GitHub Auth token and run again."
    exit 1
fi

# Base directory
BASE_DIR=~/NFCEmu
SYSTEMD_SERVICES_DIR="/etc/systemd/system"
# URLs of the services
NFC_EMULATOR_URL="https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/main/nfc-emulator.service"
SCREEN_SLEEP_MANAGER_URL="https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/main/screen-sleep-manager.service"

# Check if it's a fresh install or an update
if [[ -d "${BASE_DIR}/NFC-TerminalGUI-main" ]]; then
    UPDATE=true
else
    UPDATE=false
fi

# Display messages in big font
display_message() {
    echo -e "\n\n"
    echo "##################################################"
    echo "# #"
    echo "# $1 #"
    echo "# #"
    echo "##################################################"
    echo -e "\n\n"
}

# Start message
if [ "$UPDATE" = true ]; then
    display_message "Updating NFCEmulator"
else
    display_message "Installing NFCEmulator"
fi

# Create the base directory if it doesn't exist
mkdir -p "${BASE_DIR}"

# Download and extract the repositories
download_and_extract() {
    local repo_url="$1"
    local folder_name="$2"
    local output_zip="${BASE_DIR}/${folder_name}.zip"

    # Download the repository
    curl -s -H "Authorization: token ${TOKEN}" -L "${repo_url}" -o "${output_zip}" &
    # Start the spinner animation
    spinner $! &
    # Wait for download to complete
    wait

    # Extract the repository
    unzip -o -q "${output_zip}" -d "${BASE_DIR}"
    # rm "${output_zip}" # Remove the downloaded zip file
}

# Download and extract repositories in parallel
download_and_extract "https://github.com/Osman-Ashraf/NFC-TerminalGUI/archive/refs/heads/main.zip" "NFC-TerminalGUI" &

# Wait for both downloads to complete
wait

# Clean up and setup NFC-TerminalGUI
cd "${BASE_DIR}/NFC-TerminalGUI-main" || exit
shopt -s extglob # Enable extended globbing
rm -rf !("NFCD_GUI")
cd NFCD_GUI || exit

# Check if requirements are already installed
if ! pip3 freeze | grep -q -f requirements.txt; then
    pip3 install -r requirements.txt &
    spinner $! &
    wait
fi

# Clean up and setup NFCEmulator
cd "${BASE_DIR}/NFCEmulator-1-nfc-communicator-python-port" || exit
rm -rf !("Firmware")
cd Firmware || exit
rm -rf !("RPi_AndroidHCE")
cd RPi_AndroidHCE || exit
make all &
spinner $! &
wait

# Get run script
cd ${BASE_DIR} || exit
wget https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/main/run.sh -O ${BASE_DIR}/run.sh
wait
chmod +x run.sh

# Download the service files
wget $NFC_EMULATOR_URL -O ${SYSTEMD_SERVICES_DIR}/nfc-emulator.service
wait
wget $SCREEN_SLEEP_MANAGER_URL -O ${SYSTEMD_SERVICES_DIR}/screen-sleep-manager.service
wait
# Reload the systemd daemon to recognize the new service files
systemctl daemon-reload

# Function to check and start a service if it's not running
check_and_start_service() {
    SERVICE_NAME=$1
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo "${SERVICE_NAME} is already running."
    else
        echo "${SERVICE_NAME} is not running. Starting it now..."
        systemctl enable ${SERVICE_NAME}
        systemctl start ${SERVICE_NAME}
    fi
}

# Check and start nfc-emulator.service
check_and_start_service nfc-emulator.service

# Check and start screen-sleep-manager.service
check_and_start_service screen-sleep-manager.service

# End message
if [ "$UPDATE" = true ]; then
    display_message "NFCEmulator Updated"
    rm -rf $BASE_DIR/*.zip
else
    display_message "NFCEmulator Installed"
    rm -rf $BASE_DIR/*.zip
    # Print status of the services
    systemctl status nfc-emulator.service
    systemctl status screen-sleep-manager.service
fi
