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

case $1 in
	"initialize")
	echo "Initializing CS44600..."
	pigs w $rstGpio 1 # Take CS44600 out of it's reset state
	sleep 2 # Give CS44600 time to initialize before setting any registers
	i2cHandle=$(pigs i2co $i2cBus 0x4c 0) # Open I2C handle
	pigs i2cwb $i2cHandle 0x04 0xC0 # Misc. Config -> Digital Interface Format -> TDM
	pigs i2cwb $i2cHandle 0x31 0x04 # PWM Config -> Oversampling off, Full- / Half-bridge Settings
	pigs i2cwb $i2cHandle 0x33 0x0D # PWMOUT Delay -> 13 * PWM_MCLK
	pigs i2cwb $i2cHandle 0x06 0x00 # Volume Control -> No Auto-Mute on Errors
	pigs i2cwb $i2cHandle 0x07 0x00 # Master Volume Integer -> 0dB
	pigs i2cwb $i2cHandle 0x13 0xFF # Channel Mute -> All Muted
	pigs i2cwb $i2cHandle 0x02 0x01 # Clock Configuration and Power Control -> Power Down
	pigs i2cwb $i2cHandle 0x05 0x1B # Ramp Configuration -> Up&Down Enabled, Speed 0.65s
	pigs i2cwb $i2cHandle 0x02 0x00 # Clock Configuration and Power Control -> Power Up
	pigs i2cwb $i2cHandle 0x5A 0x55 # Secret register not in datasheet, but set by Sonos Logic Board
	pigs i2cwb $i2cHandle 0x43 0x20 # Secret register not in datasheet, but set by Sonos Logic Board
	pigs i2cwb $i2cHandle 0x5A 0x00 # Secret register not in datasheet, but set by Sonos Logic Board
	#pigs i2cwb $i2cHandle 0x07 0x01
	#pigs i2cwb $i2cHandle 0x08 0x01
	pigs i2cwb $i2cHandle 0x13 0x00 # Channel Mute -> All Unmuted
	pigs i2cwb $i2cHandle 0x05 0x08 # Ramp Configuration -> Down Enabled, Speed 0.1s
	pigs i2cwb $i2cHandle 0x03 0x20 # PWM Channel Power Down Control -> One Channel Off
	pigs i2cc $i2cHandle  # Close I2C handle
	;;
	"switchMute")
	currentStatus=$(pigs r 5)
    if [[ $currentStatus -eq 0 ]]
	then
		echo "Currently muted. Unmuting..."
		pigs w $muteGpio 1 # Unmute CS44600
    squeezeLiteCommand="play"
	else
		echo "Currently unmuted. Muting..."
		pigs w $muteGpio 0 # Mute CS44600
    squeezeLiteCommand="pause"
	fi
    
    # Control squeezelite
    for iface in "${IFACES[@]}"
    do
        read mac </sys/class/net/$iface/address
        curl -g -X POST http://$server:9000/jsonrpc.js -H 'Content-Type: application/json' -d '{"method": "slim.request", "params": ["'$mac'", ["'$squeezeLiteCommand'"]]}'
        echo $mac
    done
	;;
esac
