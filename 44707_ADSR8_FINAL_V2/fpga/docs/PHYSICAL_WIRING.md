# Physical wiring

Power off the board before wiring. The J13 SDRAM0 connector must not have an SDRAM0 device populated while its pins are being used as BLE UART.

## BLE UART bridge

This integrated project uses a JDY-31 module at **128000 baud, 8-N-1**. The phone App connects by Bluetooth Classic SPP. The USB-to-TTL adapter is only for configuring the module; disconnect its TX/RX when the module is wired to the FPGA.

| BLE module pin | Board connection | FPGA signal | Direction |
|---|---|---|---|
| TXD | J13 pin 39 / N39 | C19 / `BLE_RX` | module -> FPGA |
| RXD | J13 pin 40 / P40 | C18 / `BLE_TX` | FPGA -> module |
| VCC | board supply matching the JDY-31 module label | - | power |
| GND | board GND | - | common reference |

TXD and RXD are crossed. C18/C19 are 3.3 V I/O; do not apply 5 V logic. U15/V14 are the BL616 USB-JTAG UART pins and are intentionally not used by this project.

Use the JDY-31 module's own VCC rating; bare modules and breakout boards may differ. JDY-31 GND and FPGA GND must be connected. Leave the J13 SDRAM0 socket unoccupied while these GPIO pins are in use.

## Keys and LEDs

The eight selected PCB key outputs (capacitive or mechanical) connect to PMOD1. This variant expects idle LOW and touched HIGH, with FPGA internal pull-downs:

| Key index | FPGA pin |
|---:|---|
| 0 | Y21 |
| 1 | Y22 |
| 2 | AB21 |
| 3 | AB22 |
| 4 | AA20 |
| 5 | AA21 |
| 6 | AA19 |
| 7 | AB20 |

PMOD-LED8 is on the left PMOD (PMOD0), exactly as in `TangMega-60K-example/pmod_led_neo`:

| LED signal | FPGA pin |
|---:|---|
| `led_out[0]` | P19 |
| `led_out[1]` | R19 |
| `led_out[2]` | T21 |
| `led_out[3]` | U21 |
| `led_out[4]` | P16 |
| `led_out[5]` | R17 |
| `led_out[6]` | R18 |
| `led_out[7]` | T18 |

The LED module is common-anode/active-low: `8'hFF` is all off and a guide target drives one bit low. Use the module silk marking for the physical left-to-right LED order.

## Audio

The existing board audio path remains unchanged: FPGA I2S `Y17/AB17/AA16` drives PT8211-S and the NS4263 headphone path. `PA_EN` is held low to enable the amplifier. Recording taps the same signed digital sample before I2S, so no analog ADC or additional audio wiring is required.

Fixed-volume audio is used. No ADS1115 or pressure sensor is required. Optical OUT connects to FPGA E13 (3.3 V logic, common ground). Select pluck mode, hold a selected key, then trigger a LOW-to-HIGH optical transition. HDMI wiring and its IP remain unchanged.
