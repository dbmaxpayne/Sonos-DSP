#!/bin/bash
# I2C bus address
i2cBus=1

# squeezelite Server Address
server="192.168.178.2"

# GPIO pin numbers (BCM notation)
muteGpio=5
rstGpio=17

# Possible interface names for squeezelite
IFACES=( eth0 wlan0 )

#set -e # Exit on any error

RED='\033[0;31m'
YELLOW='\033[1;33m'
NOCOLOR='\033[0m'

# functions
initialize ()
	{
        set -e
        
		# If already initialized, reset
		 currentStatus=$(pigs r $rstGpio)
		if [[ $currentStatus -eq 1 ]]
	        then
        		echo "Resetting CS44600..."
                
                # Prevent pops
                stopAutomuter
                mute
                
                sleep 1
		        pigs w $rstGpio 0 # Reset CS44600
		        sleep 2 # Give CS44600 time to reset
		fi

		echo "Initializing CS44600..."
	        pigs w $rstGpio 1 # Take CS44600 out of it's reset state
	        sleep 2 # Give CS44600 time to initialize before setting any registers
	        i2cHandle=$(pigs i2co $i2cBus 0x4c 0) # Open I2C handle
	        pigs i2cwb $i2cHandle 0x04 0xC0 # Misc. Config -> Digital Interface Format -> TDM
	        pigs i2cwb $i2cHandle 0x31 0x04 # PWM Config -> Oversampling off, Full- / Half-bridge Settings
            #pigs i2cwb $i2cHandle 0x31 0x00 # PWM Config -> Oversampling off, Full- / Half-bridge Settings
	        pigs i2cwb $i2cHandle 0x33 0x0D # PWMOUT Delay -> 13 * PWM_MCLK
	        pigs i2cwb $i2cHandle 0x06 0x00 # Volume Control -> No Auto-Mute on Errors
	        #pigs i2cwb $i2cHandle 0x07 0x00 # Master Volume Integer -> 0dB
            setMasterVolume -15
	        pigs i2cwb $i2cHandle 0x13 0xFF # Channel Mute -> All Muted
	        pigs i2cwb $i2cHandle 0x02 0x01 # Clock Configuration and Power Control -> Power Down
	        pigs i2cwb $i2cHandle 0x05 0x1B # Ramp Configuration -> Up&Down Enabled, Speed 0.65s
	        pigs i2cwb $i2cHandle 0x02 0x00 # Clock Configuration and Power Control -> Power Up
	        pigs i2cwb $i2cHandle 0x5A 0x55 # Secret register not in datasheet, but set by Sonos Logic Board
	        pigs i2cwb $i2cHandle 0x43 0x20 # Secret register not in datasheet, but set by Sonos Logic Board
	        pigs i2cwb $i2cHandle 0x5A 0x00 # Secret register not in datasheet, but set by Sonos Logic Board
	        #pigs i2cwb $i2cHandle 0x07 0x01
	        #pigs i2cwb $i2cHandle 0x08 0x01
            sleep 2 # Give CS44600 some time to lock SRC to ADAU1401/1701
            pigs i2cwb $i2cHandle 0x03 0x20 # PWM Channel Power Down Control -> One Channel Off
	        pigs i2cwb $i2cHandle 0x13 0x00 # Channel Mute -> All Unmuted
	        pigs i2cwb $i2cHandle 0x05 0x08 # Ramp Configuration -> Down Enabled, Speed 0.1s
            
            unmute
            startAutomuter
            
	        pigs i2cc $i2cHandle  # Close I2C handle
	}

stopAutomuter()
    {
        sudo systemctl stop Sonos-Control-AutoMuter.service
    }
    
startAutomuter()
    {
        sudo systemctl start Sonos-Control-AutoMuter.service
    }

switchMute()
	{
        stopAutomuter
        
		currentStatus=$(pigs r $muteGpio)
		if [[ $currentStatus -eq 0 ]]
	        then
        	        echo "Currently muted. Unmuting..."
	                pigs w $muteGpio 1 # Unmute CS44600
                    squeezeLiteCommand='"play"'
	        else
        	        echo "Currently unmuted. Muting..."
	                pigs w $muteGpio 0 # Mute CS44600
                    squeezeLiteCommand='"power",0'
	        fi

		# Control squeezelite
		for iface in "${IFACES[@]}"
		do
		        read mac </sys/class/net/$iface/address
		        curl -g -X POST http://$server:9000/jsonrpc.js -H 'Content-Type: application/json' -d '{"method": "slim.request", "params": ["'$mac'", ['$squeezeLiteCommand']]}'
		        echo $mac
		done
        
        startAutomuter
	}
    
mute()
    {
        echo "Muting..."
        pigs w $muteGpio 0 # Mute CS44600
    }

unmute()
    {
        echo "Unmuting..."
        pigs w $muteGpio 1 # Unmute CS44600
    }

twosComplement()
    {
        x=$1
        [ "$x" -gt 127 ] && ((x=x-256))
        echo "$x"
    }

getStatus ()
	{
        i2cHandle=$(pigs i2co $i2cBus 0x4c 0) # Open I2C handle
        echo "Event register: $(pigs i2cri $i2cHandle 0x2a 1 | awk '{print $2}')"
        echo "Master volume: $(twosComplement $(pigs i2cri $i2cHandle 0x07 1 | awk '{print $2}'))dB"
        echo "Register 0x02: $(pigs i2cri $i2cHandle 0x02 1 | awk '{print $2}') # Clock Configuration and Power Control -> Power Down"
        echo "Register 0x03: $(pigs i2cri $i2cHandle 0x03 1 | awk '{print $2}') # PWM Channel Power Down Control -> One Channel Off"
        echo "Register 0x04: $(pigs i2cri $i2cHandle 0x04 1 | awk '{print $2}') # Misc. Config -> Digital Interface Format -> TDM"
        echo "Register 0x05: $(pigs i2cri $i2cHandle 0x05 1 | awk '{print $2}') # Ramp Configuration -> Down Enabled, Speed 0.1s"
        echo "Register 0x06: $(pigs i2cri $i2cHandle 0x06 1 | awk '{print $2}') # Volume Control -> No Auto-Mute on Errors"
        echo "Register 0x12: $(pigs i2cri $i2cHandle 0x13 1 | awk '{print $2}') # Channel Mute -> All Muted"
	    echo "Register 0x31: $(pigs i2cri $i2cHandle 0x31 1 | awk '{print $2}') # PWM Config -> Oversampling off, Full- / Half-bridge Settings"
	    echo "Register 0x33: $(pigs i2cri $i2cHandle 0x33 1 | awk '{print $2}') # PWMOUT Delay -> 13 * PWM_MCLK"
        echo "Register 0x43: $(pigs i2cri $i2cHandle 0x43 1 | awk '{print $2}') # Secret register not in datasheet, but set by Sonos Logic Board"
        echo "Register 0x5A: $(pigs i2cri $i2cHandle 0x5A 1 | awk '{print $2}') # Secret register not in datasheet, but set by Sonos Logic Board"

        pigs i2cc $i2cHandle  # Close I2C handle
    }

monitorSilence()
	{
        # Wait on service start to let CS44600 acquire an SRC_LOCK first
        sleep 10
        
        while [ true ]
        do
            alsaStatus=$(cat /proc/asound/card*/pcm*/sub*/status)
            currentStatus=$(pigs r $muteGpio)
            if [[ $alsaStatus == *"RUNNING"* && currentStatus -eq 0 ]]
                then
                    unmute
                    currentStatus=1
            elif [[ $alsaStatus != *"RUNNING"* && currentStatus -eq 1 ]]
                then
                    sleep 3
                    mute
                    currentStatus=0
            fi
            
            sleep 1
        done
	}
    
boot()
	{
		initialize
		#sleep 2
		#switchMute
	}
    
install()
	{
        set -e
        
        # Install prerequisites
        echo -e "${YELLOW}Installing prerequisites${NOCOLOR}"
        sudo apt update
        sudo apt install -y git python3 python3-pip pipx
        
        # Install AutoMuter
        echo -e "${YELLOW}Installing AutoMuter service${NOCOLOR}"
        sudo cp ./Files/etc/systemd/system/Sonos-Control-AutoMuter.service /etc/systemd/system
        sudo systemctl daemon-reload
        sudo systemctl enable Sonos-Control-AutoMuter.service
        
        # Configure triggerhappy
        echo -e "${YELLOW}Setting up Triggerhappy daemon${NOCOLOR}"
        sudo cp -R ./Files/etc/triggerhappy /etc
        sudo sed -i 's/DAEMON_OPTS=""/DAEMON_OPTS="--user pi"/' /etc/default/triggerhappy
        sudo sed -i 's/nobody/pi/' /etc/init.d/triggerhappy
        sudo sed -i 's/nobody/pi/' /lib/systemd/system/triggerhappy.service
        sudo systemctl daemon-reload
        sudo systemctl enable triggerhappy.service
        
        # Install pigpio
        echo -e "${YELLOW}Installing pigpio${NOCOLOR}"
        sudo apt install -y pigpio libgtk-3-0
        sudo cp -R ./Files/etc/systemd/system/pigpiod.service.d /etc/systemd/system
        sudo systemctl daemon-reload
        sudo systemctl enable pigpiod.service
        
        # Install picscope
        echo -e "${YELLOW}Installing PiScope${NOCOLOR}"
        wget -N abyz.me.uk/rpi/pigpio/piscope.tar
        tar xvf piscope.tar
        cd PISCOPE
        make hf
        make install
        cd ..
    
        # Set crontab for autostart commands
        echo -e "${YELLOW}Setting up crontab${NOCOLOR}"
        sudo crontab ./Files/crontab-root
        
        # Compile dtoverlay file for ADAU1701
        echo -e "${YELLOW}Installing DTOverlay for ADAU1401/1701${NOCOLOR}"
        sudo dtc -I dts -O dtb ./Files/sonos-adau1701_i2s.dts -o /boot/overlays/sonos-adau1701_i2s.dtbo
        
        # Install alsa and config
        echo -e "${YELLOW}Installing and configuring ALSA${NOCOLOR}"
        sudo apt install -y alsa-utils libasound2-plugins
        sudo cp ./Files/etc/asound.conf /etc
        
        # Install squeezelite
        echo -e "${YELLOW}Installing squeezelite audio player${NOCOLOR}"
        sudo apt install -y squeezelite
        
        # Install sigmadsp
        echo -e "${YELLOW}Installing sigmadsp...${NOCOLOR}"
        echo -e "${RED}If the installation fails, logon to a new shell and run this script again${NOCOLOR}"
        [ ! -d "./sigmadsp" ] && git clone https://github.com/elagil/sigmadsp.git
        # Fix externally-managed-environment message, pipx is installed via apt
        sed -i 's/python3 -m pip install --user pipx/#python3 -m pip install --user pipx/' ./sigmadsp/install.sh
        cd sigmadsp
        ./install.sh
        cd ..
        sudo cp -R ./Files/var/lib/sigmadsp /var/lib
        
        # Install ecomet library to program EEPROM of ADAU1401/1701
        echo -e "${YELLOW}Installing ecomet_i2c_raspberry_tools...${NOCOLOR}"
        python3 -m venv ./ecomet-i2c-sensors-venv
        source ./ecomet-i2c-sensors-venv/bin/activate
        python3 -m pip install ecomet-i2c-sensors colorama
        deactivate
        [ ! -d "./ecomet_i2c_raspberry_tools" ] && git clone https://github.com/mamin27/ecomet_i2c_raspberry_tools
        sudo cp -R ./Files/home/pi/.comet /home/pi
        read -p "Do you want write the firmware to ADAU1401/1701's E2PROM? (Type 'y' for yes) " yn
        [ $yn == "y" ] && writeE2PROM
        [ $yn != "y" ] && echo "Not writing E2PROM"
        
        # Set /boot/config.txt
        echo -e "${YELLOW}Installing /boot/config.txt${NOCOLOR}"
        sudo cp ./Files/boot/config.txt /boot
        
		# Install and setup Bluetooth
        echo -e "${YELLOW}Installing and setting up Bluetooth functionality${NOCOLOR}"
        sudo apt install -y bluez-alsa-utils bluez-tools
        [ ! -d "./PiZero-Bluetooth-Audio-Receiver" ] && git clone https://github.com/JasonLG1979/PiZero-Bluetooth-Audio-Receiver.git
        cd PiZero-Bluetooth-Audio-Receiver
        sudo mkdir -p /usr/local/share/sounds/__custom
        sudo cp device-added.wav /usr/local/share/sounds/__custom/
        sudo cp device-removed.wav /usr/local/share/sounds/__custom/
        sudo cp discoverable.wav /usr/local/share/sounds/__custom/
        cd ..
        sudo addgroup --system bluealsa
        sudo adduser --system --disabled-password --disabled-login --no-create-home --ingroup bluealsa bluealsa
        sudo adduser bluealsa bluetooth
        sudo adduser bluealsa audio
        sudo addgroup --system bt-agent
        sudo adduser --system --disabled-password --disabled-login --no-create-home --ingroup bt-agent bt-agent
        sudo adduser bt-agent bluetooth
        sudo sed -i 's/#Class = 0x000100/Class = 0x200428/' /etc/bluetooth/main.conf
        sudo sed -i 's/#DiscoverableTimeout = 0/DiscoverableTimeout = 0/' /etc/bluetooth/main.conf
        sudo sed -i 's/#FastConnectable = false/FastConnectable = true/' /etc/bluetooth/main.conf
        sudo sed -i 's/<policy user="root">/<policy user="bluealsa">/' /etc/dbus-1/system.d/bluealsa.conf
        sudo cp -R ./Files/etc/systemd/system/bluetooth.service.d /etc/systemd/system
        sudo cp ./Files/etc/systemd/system/bluealsa.service /etc/systemd/system
        sudo cp ./Files/etc/systemd/system/bluealsa-aplay.service /etc/systemd/system
        sudo cp ./Files/etc/systemd/system/bt-agent.service /etc/systemd/system
        sudo cp ./Files/etc/systemd/system/bt-discovery.service /etc/systemd/system
        sudo systemctl daemon-reload
        # Services are managed by bluetoothOnOff function at runtime, not boot
        #sudo systemctl enable bluealsa.service
        #sudo systemctl enable bluealsa-aplay.service
        #sudo systemctl enable bt-agent.service
        #sudo systemctl enable bt-discovery.service
        sudo systemctl disable bluealsa.service
        sudo systemctl disable bluealsa-aplay.service
        sudo systemctl disable bt-agent.service
        sudo systemctl disable bt-discovery.service
        sudo systemctl disable bluetooth.service
        sudo systemctl disable bthelper@.service
        sudo systemctl daemon-reload
        sudo systemctl mask bthelper@.service
        sudo rm /lib/systemd/system/bthelper@.service
        sudo cp ./Files/usr/local/bin/bluetooth-udev /usr/local/bin
        sudo chmod 755 /usr/local/bin/bluetooth-udev
        sudo cp ./Files/etc/udev/rules.d/99-bluetooth-udev.rules /etc/udev/rules.d
        echo "* *" | sudo tee /usr/local/etc/pins
        sudo chown bt-agent:bt-agent /usr/local/etc/pins
        sudo chmod 640 /usr/local/etc/pins
        
        echo -e "${YELLOW}Installation finished. You must reboot now. Best to cut the power, too.${NOCOLOR}"
	}
bluetoothOnOff()
    {
        bluetoothStatus=$(systemctl is-active bluetooth.service)
        stopAutomuter
        muteStatus=$(pigs r $muteGpio)
        
        if [[ $bluetoothStatus == "active" ]]
        then
            echo "Disabling Bluetooth..."
        
            
            # Unmute and play sound to let the user know
            if [[ $muteStatus -eq 0 ]]
            then
                unmute
            fi
            aplay /usr/local/share/sounds/__custom/device-removed.wav
        
            # Enable WiFi
            sudo rfkill unblock wifi
        
            # Stop all Bluetooth services
            sudo systemctl stop bluealsa-aplay.service
            sudo systemctl stop bluealsa.service
            sudo systemctl stop bt-agent.service
            sudo systemctl stop bt-discovery.service
            sudo systemctl stop bluetooth.service
            
            # Start squeezelite as WiFi is back up
            sudo systemctl start squeezelite
            
            # Allow CPU to throttle
            # Moved to /boot/config.txt as RPi0 was weird with ondemand
            #sudo sh -c "echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        else
            echo "Enabling Bluetooth..."
            
            # Stop squeezelite as WiFi is down anyway
            sudo systemctl stop squeezelite
            
            # Disable WiFi to reduce stuttering
            sudo rfkill block wifi
            
            # Start all Bluetooth services
            sudo systemctl start bluetooth.service
            sudo systemctl start bt-agent.service
            sudo systemctl start bluealsa-aplay.service
            sudo systemctl start bluealsa.service
            
            # This service plays a sound, so we unmute
            if [[ $muteStatus -eq 0 ]]
            then
                unmute
            fi
            sudo systemctl start bt-discovery.service
            sleep 3
            
            # Set CPU to max performance to reduce stuttering
            # Moved to /boot/config.txt as RPi0 was weird with ondemand
            #sudo sh -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
        fi
        
        startAutomuter
    }

setMasterVolume()
    {
        dBvolume=$1
        if [[ $dBvolume -lt 0 && $dBvolume -ge -127 ]]
        then
            dBvolume=$((256+$dBvolume))
        elif [[ $dBvolume -lt -127 ]]
        then
            dBvolume=129
        elif [[ $dBvolume -gt 24 ]]
        then
            dBvolume=24
        fi
        
        if [ ! $i2cHandle ]
        then
            i2cVolumeHandle=$(pigs i2co $i2cBus 0x4c 0) # Open I2C handle
        else
            i2cVolumeHandle=$i2cHandle
        fi

        pigs i2cwb $i2cVolumeHandle 0x07 $dBvolume
        [ ! $i2cHandle ] && pigs i2cc $i2cVolumeHandle  # Close I2C handle
        
        echo "Volume set to $1 dB"
    }
    
writeE2PROM()
    {
        echo -e "${YELLOW}Entering Python VENV ecomet-i2c-sensors-venv${NOCOLOR}" 
        source ./ecomet-i2c-sensors-venv/bin/activate
        python ./ecomet_i2c_raspberry_tools/bin/eeprom_mng.py -w -f ./Files/E2Prom.pshex -p 24c64
        deactivate
    }
 
# end functions

case $1 in
	"initialize")
    		initialize
	;;
	"switchMute")
		switchMute
    ;;
	"getStatus")
		getStatus
    ;;
	"boot")
		boot
	;;
    "monitorSilence")
		monitorSilence
	;;
    "install")
		install
	;;
    "muteKeyPress")
		echo $(date +"%s") > /run/lock/Sonos-Control.muteKeyTimestamp
	;;
    "muteKeyRelease")
        if [[ -f "/run/lock/Sonos-Control.muteKeyTimestamp" ]]
        then
            read muteKeyLastPressed < /run/lock/Sonos-Control.muteKeyTimestamp
            pressTime=$(($(date +"%s") - $muteKeyLastPressed))
        else
            pressTime=0
        fi
        
        echo $pressTime
        if [[ $pressTime -ge 5 ]]
        then
            bluetoothOnOff
        else
            switchMute
        fi
        
        rm /run/lock/Sonos-Control.muteKeyTimestamp
	;;
    "setMasterVolume")
        setMasterVolume $2
    ;;
    "writeE2PROM")
        writeE2PROM
    ;;
esac
