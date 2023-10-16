# Sonos-DSP
Make Sonos Play:5 Gen. 1 recycle-mode speakers sing again

# Introduction
This project stems from four Sonos Play:5 that I acquired unbeknownst of the so called Recycle Mode which basically bricked the devices intenionally by Sonos after offering a 30% discount on the newer Gen 2 speakers to the original owner.
Of course the original owner did not tell me that he underwent this process and so I used the speakers as basic line-in devices for about six months.
From one day to another they all four stopped working.
Upon installing the app and trying to see what was wrong, I got the message that they were in Recycle Mode and could not be set-up again.
I was like "what?!" and consulted the internet for help.
Quickly it turned out that a lot of customers were angry about the same thing and that Sonos actually stopped bricking the devices after some pressure from the community and also because they were deliberately making rubbish of perfectly good hardware.
However, the official statement was (and still is in 10.2023), that bricked devices remain bricked.
I contacted Sonos about this twice and tried to acquire a reset firmware so I could use line-in again.
They were as helpful as you'd expect for a company that does not offer repairs or schematics and thinks of a recycle mode for working hardware...

Having spent some money on the devices I was obviously not pleased and tried to find a way around this.
This repo is the result of my work and I hope it helps anyone with old Play:5 or even other devices to make them sing again :)

>[!WARNING]
>Disclaimer: All information in this repo is delivered as a courtesy. Please think about what you do as do not take any responsibility for destroying your devices or your health.
>Remember: Electricity is dangerous and there is a risk of suffering an electric shock when opening these devices.

> [!NOTE]
> You can find datasheets in the corresponding subfolder.
> These are mostly not done by me and have all rights reserved to their creators.

# General Information
## Needed hard- and software
- Sonos Play:5 Speaker (obviously)
- Analog Devices ADAU1701-based Audio DSP board
  - e.g. Wondom APM2 (I used this for my initial tests - worked really well)
  - e.g. Cheap ADAU1701-based development board from AliExpress
  - (USB programmer for the DSP board. e.g. Wondom ICP1) [This can be replaced by a TCPIP programmer like this one [blus-audio/sigmadsp](https://github.com/blus-audio/sigmadsp)]
- Raspberry Pi or similar SBC / Microcontroller
- Shielded wires for I2S digital sound data (e.g. RG178 coax cable)
- Breadboard cables
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
| 17              | GND      |                           | 18              |
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
- There is no need for LED resisors. These are on the button board
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
> Use only one GND connection from board to board to avoid ground loops

> [!NOTE]
> Use shielded wires for all I2S lines.
> The CS44600 is very picky about correct clocks and has an automatic sampling rate selector built-in.
> If you use normal breadboard connector you will NOT get it working as we are working with a very high frequency of 12.288 Mhz which is 12.228 Million pulses per second.
> In my original test design I used two breadboard cables. One was stripped of its insulating and then wrapped in aluminium foil with the second data wire inside.
> Don't forget to insulate it again with some sticky tape or heat shrink tubes.
> This worked well, but the cables were very stiff.
> I switched to RG178 coax wire which I bought off AliExpress for like 8€/10m.
>
> Make sure to only connect one side of this to GND to avoid ground loops.

## Main Wiring
| Sonos Mainboard Pin #          | DSP Pin          | Raspberry Pi GPIO #   |
| :---                           |:---              |:---                   |
| 28 - DAI_SCLK / DAI_MCLK (I2S) | MP11 - Out_BCLK  | GPIO 18 - I2S CLK In  |
| 32 - DAI_LRCK (I2S)            | MP10 - Out_LRCLK | GPIO 19 - I2S LRCLK   |
| 34 - DAI_LRCK (I2S)            | MP10 - Out_LRCLK | GPIO 20 - I2S Data In |
| 36 - SCL (I2C)                 | (SCL)            | GPIO  3 - I2C SCL     |
| 38 - SDA (I2C)                 | (SDA)            | GPIO  2 - I2C SCL     |
| 42 - RST#                      |                  | GPIO 17               |
| 44 - MUTE#                     |                  | GPIO 5                |
| GND (only one per board!)      | GND              | GND                   |

## Button Wiring
| Pin           | DSP Pin | Raspberry Pi GPIO # |
| :---          | :---    | :---                |
| 2 - Mute      |         | GPIO 24             |
| 5 OR 7 - GND  | GND     |                     |
| 9 - Volume +  | MP1     |                     |
| 10 - Volume - | MP7     |                     |
