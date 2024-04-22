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

create_nfc_app_service() {
    # Service file content
    SERVICE_CONTENT="[Unit]
    Description=nfc-app
    Wants=graphical.target
    After=graphical.target
    
    [Service]
    Environment=DISPLAY=:0.0
    Environment=XAUTHORITY=/home/admin/.Xauthority
    Type=simple
    ExecStart=/bin/bash /home/kiosk/kiosk_app/run.sh
    Restart=on-abort
    User=kiosk
    Group=kiosk
    
    [Install]
    WantedBy=graphical.target"
    
    # File paths
    SERVICE_FILE="/etc/systemd/system/nfc-app.service"
    SCRIPT_PATH="/home/kiosk/kiosk_app/run.sh"
    
    # Create the service file
    echo "$SERVICE_CONTENT" | sudo tee "$SERVICE_FILE" > /dev/null
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    # Enable the service to start on boot
    sudo systemctl enable nfc-app
    
    # Display service status
    sudo systemctl status nfc-app

}

create_reboot_service() {
    # Define the path to the service file
    SERVICE_FILE="/lib/systemd/system/rebootbinary.service"

    # Check if the service file already exists
    if [ -e "$SERVICE_FILE" ]; then
        echo "The service file already exists: $SERVICE_FILE"
    else
        # Create the service file
        echo "# /lib/systemd/system/rebootbinary.service" | sudo tee "$SERVICE_FILE" > /dev/null
        echo "" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "[Unit]" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "Description=Reboot Binary Service" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "[Service]" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "Type=oneshot" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "ExecStart=/home/pie/NFCEmu/reboot.sh" | sudo tee -a "$SERVICE_FILE" > /dev/null
        echo "User=pie" | sudo tee -a "$SERVICE_FILE" > /dev/null
    
        log_info "Service file created: $SERVICE_FILE"
    fi
}

create_reboot_timer() {
    TIMER_FILE="/lib/systemd/system/rebootbinary.timer"

    # Check if the timer file already exists
    if [ -e "$TIMER_FILE" ]; then
        echo "The timer file already exists: $TIMER_FILE"
    else
        # Create the timer file
        echo "# /lib/systemd/system/rebootbinary.timer" | sudo tee "$TIMER_FILE" > /dev/null
        echo "" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "[Unit]" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "Description=Reboot pi at 2 am daily" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "[Timer]" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "Unit=rebootbinary.service" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "OnCalendar=*-*-* 02:00:00" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "[Install]" | sudo tee -a "$TIMER_FILE" > /dev/null
        echo "WantedBy=timers.target" | sudo tee -a "$TIMER_FILE" > /dev/null
    
        log_info "Timer file created: $TIMER_FILE"
    
        # Reload systemd daemons
        sudo systemctl daemon-reload
    
        # Enable the timer
        sudo systemctl enable rebootbinary.timer
    
        # Start the timer
        sudo systemctl start rebootbinary.timer
    fi
}


reboot_five() {
    local delay=1
    printf "$red Rebooting in 5...$reset"
    for ((i = 4; i > 0; i--)); do
        printf "\b\b\b\b"
        printf "$red$i...$reset"
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

# ---------------------------------------------------------------
# --------------------- Create a kiosk user ---------------------
# ---------------------------------------------------------------

# Define the username
username="kiosk"
password="kiosk"

# Check if the user already exists
if id "$username" &>/dev/null; then
    log_info "User '$username' already exists."
else
    # Create the user
    sudo adduser "$username"<<EOF
kiosk
kiosk
EOF
    
    # Set a password for the user
    echo "$username:$password" | sudo chpasswd
    
    log_info "User '$username' created successfully."
fi

sudo mkdir /home/kiosk/kiosk_app

sudo chown -R kiosk:kiosk /home/kiosk/kiosk_app


# Base directory
BASE_DIR=/home/kiosk/kiosk_app

# Define the files paths
lightdm_conf="/etc/lightdm/lightdm.conf"

# Check if it's a fresh install or an update
if [[ -d "${BASE_DIR}/NFC-TerminalGUI-main" && -d "${BASE_DIR}/NFCEmulator-1-main" ]]; then
    log_info "Directories already exist. Updating them."
    UPDATE=true 
else
    log_info "Performing a Fresh Install."
    UPDATE=false
    
    # Update the package list
    sudo apt-get update
    sudo apt-get upgrade -y

    # Install necessary packages
    sudo apt-get install -y git autoconf libtool libusb-dev unclutter

    # Enable SPI interface using raspi-config
    log_info "Enabling the SPI interface on Pi..."
    sudo raspi-config nonint do_spi 0

    # Clone the libnfc repository
    log_info "Cloning the libnfc repo..."
    cd ~
    git clone https://github.com/nfc-tools/libnfc

    # Navigate to the libnfc directory and create the /etc/nfc directory
    cd libnfc
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

# Use sed to replace the autologin-user property
sudo sed -i 's/^autologin-user=.*/autologin-user=kiosk/' "$lightdm_conf"
log_info "autologin-user property in $lightdm_conf has been set to 'kiosk'."

# Start message
if [ "$UPDATE" = true ]; then
    display_message "UPDATING NFC TERMINAL APP"
else
    display_message "INSTAllING NFC TERMINAL APP"
fi

# Create the base directory if it doesn't exist
sudo mkdir -p "${BASE_DIR}"

# Download and extract the repositories
download_and_extract() {
    local repo_url="$1"
    local folder_name="$2"
    local output_zip="${BASE_DIR}/${folder_name}.zip"

    # Download the repository
    log_info "Downloading the ${folder_name} repo..."
    sudo -u kiosk curl -s -H "Authorization: token ${TOKEN}" -L "${repo_url}" -o "${output_zip}" &

    # Start the spinner animation
    spinner $! &

    # Wait for download to complete
    wait

    # Extract the repository
    log_info "Extracting the ${folder_name}.zip..."
    sudo -u kiosk unzip -o -q "${output_zip}" -d "${BASE_DIR}"
    # rm "${output_zip}"  # Remove the downloaded zip file
}

# Download and extract repositories
download_and_extract "https://github.com/Osman-Ashraf/NFC-TerminalGUI/archive/refs/heads/main.zip" "NFC-TerminalGUI"
download_and_extract "https://github.com/Osman-Ashraf/NFCEmulator-1/archive/refs/heads/main.zip" "NFCEmulator-1-main"

# Wait for both downloads to complete
wait

# Clean up and setup NFC-TerminalGUI
su - "$username" -c '
# Commands to be executed as the specified user
# For example, entering a password
echo "kiosk"
' 2>&1 >> /tmp/su_error.log

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
wget https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/ali-yasir-binairy-patch-1/run.sh -O ${BASE_DIR}/run.sh 
wait
log_info "Making the run script..."
chmod +x run.sh
log_info "run script make completed."
wget https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/ali-yasir-binairy-patch-1/reboot.sh -O ${BASE_DIR}/reboot.sh 
wait
log_info "Making the reboot script..."
chmod +x run.sh
log_info "reboot script make completed."

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

create_nfc_app_service

# Perform a reboot
reboot_five
