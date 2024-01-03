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
if [[ -d "${BASE_DIR}/NFC-TerminalGUI-main" && -d "${BASE_DIR}/NFCEmulator-1-main" ]]; then
    UPDATE=true
else
    UPDATE=false
    # Update the package list
    sudo apt-get update

    # Upgrade installed packages
    sudo apt-get upgrade -y

    # Install necessary packages
    sudo apt-get install -y git autoconf libtool libusb-dev

    # Enable SPI interface using raspi-config
    sudo raspi-config nonint do_spi 0

    # Clone the libnfc repository
    cd ~
    git clone https://github.com/nfc-tools/libnfc

    # Navigate to the libnfc directory
    cd libnfc

    # Create the /etc/nfc directory if it doesn't exist
    sudo mkdir -p /etc/nfc

    file_path="/etc/nfc/libnfc.conf"
    text_to_add="allow_autoscan = true
    device.name = \"PN532 over SPI\"
    device.connstring = \"pn532_spi:/dev/spidev0.0:100000\""
    
    # Check if the file contains the text
    if ! grep -q "$text_to_add" "$file_path"; then
        # If not found, append the text to the file
        echo "$text_to_add" | sudo tee -a "$file_path" > /dev/null
        echo "Text added to $file_path."
    else
        echo "Text already present in $file_path."
    fi

    # Run additional setup commands
    autoreconf -vis
    ./configure --with-drivers=pn532_spi --sysconfdir=/etc --prefix=/usr
    make
    sudo make install all
fi

# Display messages in big font
display_installing_nfc_terminal() {
    orange=$(tput setaf 3)  # ANSI code for orange
    # ASCII art for the banner
    banner="
    
    ${orange}
    ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ██╗███╗   ██╗ ██████╗                    
    ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██║████╗  ██║██╔════╝                    
    ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     ██║██╔██╗ ██║██║  ███╗                   
    ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██║██║╚██╗██║██║   ██║                   
    ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗██║██║ ╚████║╚██████╔╝                   
    ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝                    
                                                                                                   
    ███╗   ██╗███████╗ ██████╗    ████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗     
    ████╗  ██║██╔════╝██╔════╝    ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║     
    ██╔██╗ ██║█████╗  ██║            ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║     
    ██║╚██╗██║██╔══╝  ██║            ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║     
    ██║ ╚████║██║     ╚██████╗       ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
    ╚═╝  ╚═══╝╚═╝      ╚═════╝       ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
                                      
                                                                                                                                                                                                                                                                                                                                                          
    "

    # Print the banner
    echo -e "${banner}"
}

display_updating_nfc_terminal() {
    orange=$(tput setaf 3)  # ANSI code for orange
    # ASCII art for the banner
    banner="
    
    ${orange}
    ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗██╗███╗   ██╗ ██████╗                                
    ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██║████╗  ██║██╔════╝                                
    ██║   ██║██████╔╝██║  ██║███████║   ██║   ██║██╔██╗ ██║██║  ███╗                               
    ██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██║██║╚██╗██║██║   ██║                               
    ╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ██║██║ ╚████║╚██████╔╝                               
     ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝╚═╝  ╚═══╝ ╚═════╝                                
                                                                                                   
    ███╗   ██╗███████╗ ██████╗    ████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗     
    ████╗  ██║██╔════╝██╔════╝    ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║     
    ██╔██╗ ██║█████╗  ██║            ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║     
    ██║╚██╗██║██╔══╝  ██║            ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║     
    ██║ ╚████║██║     ╚██████╗       ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
    ╚═╝  ╚═══╝╚═╝      ╚═════╝       ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
                                                                                               
                                                                                                                                                                                                                                                                                                                                               
    "

    # Print the banner
    echo -e "${banner}"
}

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

# Start message
if [ "$UPDATE" = true ]; then
    display_updating_nfc_terminal
else
    display_installing_nfc_terminal
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
make all & 
spinner $! &
wait

# Get run script
cd ${BASE_DIR} || exit
wget https://raw.githubusercontent.com/Osman-Ashraf/NFCEmu-QuickStart/ali-yasir-binairy-patch-1/run.sh -O ${BASE_DIR}/run.sh 
wait
chmod +x run.sh

# Make android_hce.sh
# cd "${BASE_DIR}/NFCEmulator-1-main/Firmware/RPi_AndroidHCE" || exit
# gcc -o android_hce android_hce.cpp -lnfc

# End message
if [ "$UPDATE" = true ]; then
    display_message "NFCEmulator Updated"
    
    rm -rf $BASE_DIR/*.zip
else
    display_message "NFCEmulator Installed"
    rm -rf $BASE_DIR/*.zip
fi
