#!/bin/bash

# Spinner animation
spinner() {
    local pid=$1
    local delay=0.05
    local frames=("■□□□" "□■□□" "□□■□" "□□□■")
    local frame_count=${#frames[@]}
    local current_frame=0
    
    printf "\n"

    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        printf "\e[38;5;208m%s\e[0m " "${frames[$current_frame]}"
        current_frame=$(( (current_frame + 1) % frame_count ))
        sleep $delay
        printf "\b\b\b\b\b"
    done

    printf "      \b\b\b\b\b"
}

# Display messages in big font
display_message() {
    local msg="$1"
    local box_top="╭"
    local box_bottom="╰"

    for ((i = 0; i < ${#msg} - 2; i++)); do
        box_top+="─"
        box_bottom+="─"
    done

    box_top+="---··"
    box_bottom+="---··"

    echo -e "\n"
    echo -e "\e[38;5;208m$box_top\e[0m"
    printf "\e[38;5;208m│ \e[1m%-${#msg}s\e[38;5;208m \e[0m\n" "$msg"
    echo -e "\e[38;5;208m$box_bottom\e[0m"
    echo -e "\n"
}

log_info() {
    local msg="$1"
    green=$(tput setaf 2)  # ANSI code for orange
    reset=$(tput sgr0)

    printf "$green※ %s$reset\n" "$msg"
}

log_error() {
    local msg="$1"
    red=$(tput setaf 1)  # ANSI code for orange
    reset=$(tput sgr0)

    printf "$red※ %s$reset\n" "$msg"
}

reboot_five() {
    local delay=1
    for ((i = 4; i > 0; i--)); do
        echo "$red Rebooting in $i...$reset"
        sleep $delay
    done

    sudo reboot
}

# Check for internet connection
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    log_error "No internet connection. Please check your connection and try again."
    exit 1
fi

# Check if TOKEN environment variable is set and not empty
if [[ -z "${TOKEN}" ]]; then
    log_error "Please set GitHub Auth token and run again."
    exit 1
fi

# Base directory
BASE_DIR=~/NFCEmu

# Check if it's a fresh install or an update
if [[ -d "${BASE_DIR}/NFC-TerminalGUI-main" && -d "${BASE_DIR}/NFCEmulator-1-main" ]]; then
    log_info "Directories already exist. Updating them."
    UPDATE=true 
else
    log_info "Performing a Fresh Install."
    UPDATE=false
    # Update the package list
    # sudo apt-get update

    # Upgrade installed packages
    # sudo apt-get upgrade -y

    # Install necessary packages
    sudo apt-get install -y git autoconf libtool libusb-dev

    # Enable SPI interface using raspi-config
    log_info "Enabling the SPI interface on Pi..."
    sudo raspi-config nonint do_spi 0

    # Define the command to be added to autostart
    AUTOSTART_COMMAND="@bash /home/pie/NFCEmu/run.sh"

    # Add the command to the end of autostart file
    log_info "Adding the script to autostart file"
    echo "$AUTOSTART_COMMAND" | sudo tee -a /etc/xdg/lxsession/LXDE-pi/autostart


    # Clone the libnfc repository
    log_info "Cloning the libnfc repo..."
    cd ~
    git clone https://github.com/nfc-tools/libnfc

    # Navigate to the libnfc directory
    cd libnfc

    # Create the /etc/nfc directory if it doesn't exist
    sudo mkdir -p /etc/nfc

    log_info "Adding NFC configuration to libnfc.conf..."
    file_path="/etc/nfc/libnfc.conf"
    text_to_add="allow_autoscan = true
    device.name = \"PN532 over SPI\"
    device.connstring = \"pn532_spi:/dev/spidev0.0:100000\""
    
    # Check if the file contains the text
    if ! grep -q "$text_to_add" "$file_path"; then
        # If not found, append the text to the file
        echo "$text_to_add" | sudo tee -a "$file_path" > /dev/null
        log_info "Config added to $file_path."
    else
        log_info "Config already exists. Not added."
    fi

    # Run additional setup commands
    autoreconf -vis
    ./configure --with-drivers=pn532_spi --sysconfdir=/etc --prefix=/usr
    make
    sudo make install all
fi

# Start message
if [ "$UPDATE" = true ]; then
    display_message "UPDATING NFC TERMINAL APP"
else
    display_message "INSTAllING NFC TERMINAL APP"
fi

# Create the base directory if it doesn't exist
mkdir -p "${BASE_DIR}"

# Download and extract the repositories
download_and_extract() {
    local repo_url="$1"
    local folder_name="$2"
    local output_zip="${BASE_DIR}/${folder_name}.zip"

    # Download the repository
    log_info "Downloading the ${folder_name} repo..."
    curl -s -H "Authorization: token ${TOKEN}" -L "${repo_url}" -o "${output_zip}" &

    # Start the spinner animation
    spinner $! &

    # Wait for download to complete
    wait

    # Extract the repository
    log_info "Extracting the ${folder_name}.zip..."
    unzip -o -q "${output_zip}" -d "${BASE_DIR}"
    # rm "${output_zip}"  # Remove the downloaded zip file
}

# Download and extract repositories in parallel
download_and_extract "https://github.com/Osman-Ashraf/NFC-TerminalGUI/archive/refs/heads/main.zip" "NFC-TerminalGUI" &
download_and_extract "https://github.com/Osman-Ashraf/NFCEmulator-1/archive/refs/heads/main.zip" "NFCEmulator-1-main" &

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
cd "${BASE_DIR}/NFCEmulator-1-main" || exit
rm -rf !("Firmware")
cd Firmware || exit
rm -rf !("RPi_AndroidHCE")

cd RPi_AndroidHCE || exit
log_info "Making the android_hce script..."
make all & 
spinner $! &
wait
log_info "android_hce script make completed."


# Get run script
cd ${BASE_DIR} || exit
wget https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/alpha/run.sh -O ${BASE_DIR}/run.sh 
wait
log_info "Making the run script..."
chmod +x run.sh
log_info "run script make completed."

# End message
if [ "$UPDATE" = true ]; then
    display_message "NFCEmulator Updated"

    log_info "Cleaning installation files in ${BASE_DIR}"
    rm -rf $BASE_DIR/*.zip
else
    display_message "NFCEmulator Installed"

    log_info "Cleaning installation files in ${BASE_DIR}"
    rm -rf $BASE_DIR/*.zip
fi

# Define variables
DESKTOP_FILE="/etc/xdg/autostart/display.desktop"
SCRIPT_NAME="run.sh"
SCRIPT_EXEC="/home/pi/NFCEmu/run.sh"

# Create the .desktop file
echo "[Desktop Entry]" | sudo tee "$DESKTOP_FILE" > /dev/null
echo "Name=$SCRIPT_NAME" | sudo tee -a "$DESKTOP_FILE" > /dev/null
echo "Exec=$SCRIPT_EXEC" | sudo tee -a "$DESKTOP_FILE" > /dev/null


# Perform a reboot
reboot_five
