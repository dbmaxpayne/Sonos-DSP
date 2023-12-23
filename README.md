# Sonos-DSP
Make Sonos Play:5 Gen. 1 recycle-mode speakers sing again

# Introduction
This project stems from four Sonos Play:5 that I acquired unbeknownst of the so called Recycle Mode which basically bricked the devices intenionally by Sonos after offering a 30% discount on the newer Gen 2 speakers to the original owner.
Of course the original owner did not tell me that he underwent this process and so I used the speakers as basic line-in devices for about six months.
From one day to another they all four stopped working.
Upon installing the Sonos app and trying to see what was wrong, I got the message that they were in Recycle Mode and could not be set-up again.
I was like "what?!" and consulted the internet for help.
Quickly it turned out that a lot of customers were angry about the same thing and that Sonos actually stopped bricking the devices after some pressure from the community and also because they were deliberately making rubbish out of perfectly good hardware.
However, the official statement was (and still is in 10.2023), that bricked devices remain bricked.
I contacted Sonos about this twice and tried to acquire a reset firmware so I could use line-in again.
They were as helpful as you'd expect for a company that does not offer repairs or schematics and thinks of a recycle mode for working hardware...

Having spent some money on the devices I was obviously not pleased and tried to find a way around this.
This repo is the result of my work and I hope it helps anyone with old Play:5s or even other devices to make them sing again :)

>[!WARNING]
>Disclaimer: All information in this repo is delivered as a courtesy. Please think about what you do as I do not take any responsibility for destroying your devices or your health.
>Remember: Electricity is dangerous and there is a risk of suffering an electric shock when opening these devices.

> [!NOTE]
> You can find datasheets in the corresponding subfolder.
> These are mostly not done by me and have all rights reserved to their creators.

# General Information
## Needed hard- and software
- Sonos Play:5 Speaker (obviously)
- Analog Devices ADAU1701-based Audio DSP board
  - e.g. Wondom APM2 (I used this for my initial tests - worked really well)
  - e.g. Cheap ADAU1401/1701-based development board from AliExpress
  - (USB programmer for the DSP board. e.g. Wondom ICP1) [This can be replaced by a TCPIP programmer like this one [blus-audio/sigmadsp](https://github.com/blus-audio/sigmadsp)]
- Raspberry Pi or similar SBC / Microcontroller. I recommend a Zero W or Zero 2 W
- Shielded wires for I2S digital sound data (e.g. RG178 coax cable). You might get away without them or a ferrite, too.
- Alternatively: Use the provided PCB layout to make a PCB yourself. I did this at pcbway.com and was very happy with their quality.
  - 2x20 2.54mm Female Pin Header
  - 2x25 2.00mm Female Pin Header
  - Single Row 2.54mm Female and Male Pin Headers
  - Micro JST 10Pin 1.25mm Connector (You can also desolver the one on the Sonos logic board)
- Breadboard cables
- MP1584EN DC-DC Step-Down Converter to Power the RPi and ADAU1401/1701 DSP
- 20k resistor
- BC327-40 Transistor
- Soldering Iron
- Analog Devices SigmaStudio (to program the DSP)
  
## Sonos Play:5 Mainboard Connector Pinout
| Mainboard Pin # | Function | Function                  | Mainboard Pin # |
| :---            |:---      |:---                       | :---            |
| 1               | GND      |                           | 2               |
| 3               | GND      |                           | 4               |
| 5               | GND      |                           | 6               |
| 7               | GND      | +3.3V                     | 8               |
| 9               | GND      | +3.3V                     | 10              |
| 11              | GND      | +3.3V                     | 12              |
| 13              | GND      | +11.1V                    | 14              |
| 15              | GND      | +12V                      | 16              |
| 17              | GND      | Amplifier Power Enable    | 18              |
| 19              | GND      |                           | 20              |
| 21              | GND      |                           | 22              |
| 23              | GND      |                           | 24              |
| 25              | GND      |                           | 26              |
| 27              | GND      | DAI_SCLK / DAI_MCLK (I2S) | 28              |
| 29              | GND      |                           | 30              |
| 31              | GND      | DAI_LRCK (I2S)            | 32              |
| 33              | GND      | DAI_SDIN1 (I2S)           | 34              |
| 35              | GND      | SCL (I2C)                 | 36              |
| 37              | GND      | SDA (I2C)                 | 38              |
| 39              | GND      | INT                       | 40              |
| 41              | GND      | RST#                      | 42              |
| 43              | GND      | MUTE#                     | 44              |
| 45              |          |                           | 46              |
| 47              |          |                           | 48              |
| 49              |          |                           | 50              |

## Sonos Play:5 Button Connector
- Pin 1 is identified on the logic board by a white dot
- There is no need for LED resisors. These are on the button board if you use 3.3V
> [!WARNING]
> Do not drive the LEDs directly off GPIO pins. These are not strong enough!

| Pin # | Function   |
| :---  | :---       |
| 1     | Unknown    |
| 2     | Mute       |
| 3     | LED Green  |
| 4     | LED Red    |
| 5     | GND        |
| 6     | LED Orange |
| 7     | GND        |
| 8     | LED White  |
| 9     | Volume +   |
| 10    | Volume -   |

# Wiring
> [!NOTE]
> Use shielded wires for all I2S lines or at least keep them as short as possible.
> Maybe you can use unshielded wires with a ferrite. I have not tried this.
> The CS44600 is very picky about correct clocks and has an automatic sampling rate selector built-in.
> If you use normal breadboard connectors you will most likely NOT get it working as we are working with a very high frequency of 12.288 Mhz which is 12.228 Million pulses per second.
> In my original test design I used two breadboard cables. One was stripped of its insulating and then wrapped in aluminium foil with the second data wire inside.
> This outher shield was then connected to GND.
> Don't forget to insulate it again with some sticky tape or heat shrink tubes.
> This worked well, but the cables were very stiff.
> I switched to RG178 coax wire which I bought off AliExpress for like 8€/10m.
>
> After my initial tests I designed a simple drop-in PCB that removes the need of these complex wire designs.
> You can find the PCB design on this page, too.

## Main Wiring
| Sonos Mainboard Pin #          | DSP Pin            | Raspberry Pi GPIO #        |
| :---                           |:---                |:---                        |
| 28 - DAI_SCLK / DAI_MCLK (I2S) | MP11 - Out_BCLK    | GPIO 18 - I2S CLK In       |
| 32 - DAI_LRCK (I2S)            | MP10 - Out_LRCLK   | GPIO 19 - I2S LRCLK        |
| 34 - DAI_SDIN1 (I2S)           | MP6 - TDM_DATA_OUT |                            |
|                                | MP0 - TDM_DATA_IN  | GPIO 21 - I2S Data Out     |
| 36 - SCL (I2C)                 | (SCL)              | GPIO  3 - I2C SCL          |
| 38 - SDA (I2C)                 | (SDA)              | GPIO  2 - I2C SCL          |
| 42 - RST#                      |                    | GPIO 17                    |
| 44 - MUTE#                     |                    | GPIO 5                     |
| 28 - Amplifier Power Enable    |                    | GPIO 5 (Yes, connect both) |
|                                | WP                 | GPIO 26                    |
| GND                            | GND                | GND                        |

## Button Wiring
| Pin           | DSP Pin | Raspberry Pi GPIO # |
| :---          | :---    | :---                |
| 2 - Mute      |         | GPIO 6              |
| 5 OR 7 - GND  | GND     |                     |
| 9 - Volume +  | MP1     |                     |
| 10 - Volume - | MP7     |                     |

# Software / RPi Configuration
## Sonos-Control.sh
```
Sonos-Control.sh must be called to set the CS44600's registers to allow audio to pass through the signal path and to do various other things.
Check the file as it contains comments.

install:
The most important command as it will set up everything for you on a freshly installed Raspberry Pi.
It also sets up basic Bluetooth functionality.
Be aware of the fact that Bluetooth is not perfect on RPi Zero 1's.
It works for me, but it might not work for you.

initialize:
As the name suggests, this argument initializes the CS44600 after a reboot.
A series of register writes ensures proper operation of the chip.
Consult the datasheet for detailed explanation or custom settings.

getStatus:
Read all important registers of CS44600 to see if the initialization has worked.

switchMute:
Switches the mute state of the hardware and sends a signal to a possible squeezelite server to pause/resume playback.
As pin 44 and 28 of the Sonos mainboard are to be connected, it also switches on the power output stage of the board.
If pin 28 is not set to high, the volume will be very low and the speakers are basically driven from a 5V instead of a 24V source. 
```

# HowTo
- Wire everything. Maybe leave out the buttons in the beginning and everything else that complicates things
- Alternatively use my PCB layout
- Copy the folder Sonos-Control onto the RPi
- chmod +x Sonos-Control.sh
- Run Sonos-Control.sh install
- If this is the first time you do this, say yes when asked to flash the firmware. This will flash the ADAU1401/1701's firmware so we have a usable base.
- Cut the power and reboot everything
- Run 'speaker-test -t wav -c 2' and hope that you hear a sound
- If not there is probably something wrong with your wiring. Remember to use shielded wires for all I2S wires and keep them as short as possible.
  - Debug with `pigs i2cri 0 0x2a 1` and look at the ADAU1701's datasheet. This register tells you if CS44600 was able to achieve a lock to the I2S bitclocks provided by ADAU1701.
    If the SRC_UNLOCK bit is set, something is not right. If SRC_LOCK is set, but you can't hear anything, the wirings of DAI_MCLK & DAI_LRCLK are correct and the problem is either at DAI_SDIN1 or your SigmaStudio project not outputting anything.
  - You can also use piscope to see if the I2S signals are generated correctly. For this stop the pigpiod service 'sudo systemctl stop pigpiod' and run it with slightly different settings: 'sudo pigpiod -s 2 -t 0'
  Connect via SSH with X11 forwarding and run 'piscope &'

To make changes to the DSP (like change the crossover frequency or enable bass boost)
- Load Sonos-DSP.dspproj into SigmaStudio
- On 'Hardware Configuration\Config' right click on TCPIP1701, select 'Show TCPI/IP settings' and set the IP address.
- Click on 'Link Compile Download'. This will transfer the compiled program to the RPi and sigmadsp will write it to the RAM of the DSP (this is NOT permanent).
- You can now make changes to everything pretty much live.
- When everything is as you want it, go back to 'Hardware Configuration\Config' and connect the ADAU1701 IC 1 to the 'USB Interface'. Then right click the IC 1 and select 'Write latest compilation to EEPROM'.
- This will create the firmware files in a subfolder called 'Sonos-DSP_IC 2'
- Now run the PowerShell script Convert-SigmaStudioBinToEcometHex.ps1 on the corresponding bin file. This will convert it to the necessary format to flash it to the DPS's EEPROM.
- Copy the file to RPi and place it in the folder 'Sonos-Control'. The name must be 'E2Prom.pshex'. Then run 'Sonos-Control.sh writeE2PROM' which will flash it.

# Special Thanks
This project would not have been successfull without the following:
- https://sites.google.com/site/sonosdebug
- https://github.com/mamin27/ecomet_i2c_raspberry_tools
- https://github.com/blus-audio/sigmadsp
- https://github.com/JasonLG1979/PiZero-Bluetooth-Audio-Receiver
