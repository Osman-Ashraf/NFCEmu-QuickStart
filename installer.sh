#!/bin/bash

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
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

# Check if it's a fresh install or an update
if [[ -d "${BASE_DIR}/NFC-TerminalGUI-main" && -d "${BASE_DIR}/NFCEmulator-main" ]]; then
    UPDATE=true
else
    UPDATE=false
fi

# Display messages in big font
display_message() {
    echo -e "\n\n"
    echo "##################################################"
    echo "#                                                #"
    echo "#                 $1                 #"
    echo "#                                                #"
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
    rm "${output_zip}"  # Remove the downloaded zip file
}

# Download and extract repositories in parallel
download_and_extract "https://github.com/Nauman3S/NFC-TerminalGUI/archive/refs/heads/main.zip" "NFC-TerminalGUI" &
download_and_extract "https://github.com/Nauman3S/NFCEmulator/archive/refs/heads/main.zip" "NFCEmulator" &

# Wait for both downloads to complete
wait

# Clean up and setup NFC-TerminalGUI
cd "${BASE_DIR}/NFC-TerminalGUI-main" || exit
shopt -s extglob  # Enable extended globbing
rm -rf !("NFCD_GUI")
cd NFCD_GUI || exit

# Check if requirements are already installed
if ! pip3 freeze | grep -q -f requirements.txt; then
    pip3 install -r requirements.txt &
    spinner $! &
    wait
fi

# Clean up and setup NFCEmulator
cd "${BASE_DIR}/NFCEmulator-main" || exit
rm -rf !("Firmware")
cd Firmware || exit
rm -rf !("RPi_AndroidHCE")
cd RPi_AndroidHCE || exit
make all & 
spinner $! &
wait

# Get run script
cd $BASE_DIR
wget -O - https://raw.githubusercontent.com/Nauman3S/NFCEmu-QuickStart/main/run.sh | bash
chmod +x run.sh

# End message
if [ "$UPDATE" = true ]; then
    display_message "NFCEmulator Updated"
else
    display_message "NFCEmulator Installed"
fi
