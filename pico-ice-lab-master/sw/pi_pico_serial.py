#!/usr/bin/env python3
import argparse
import serial
import struct
from serial.tools import list_ports


def default_port():
    preferred_ports = []
    fallback_ports = []

    for port in list_ports.comports():
        description = (port.description or "").lower()
        manufacturer = (port.manufacturer or "").lower()

        if any(keyword in description for keyword in ("usb", "uart", "cdc")) or \
           any(keyword in manufacturer for keyword in ("raspberry", "tinyvision", "pico")):
            preferred_ports.append(port.device)
        else:
            fallback_ports.append(port.device)

    if preferred_ports:
        return preferred_ports[0]

    if fallback_ports:
        return fallback_ports[0]

    raise RuntimeError("No serial port detected. Specify one with --port COMx")


def available_ports():
    ports = []
    for port in list_ports.comports():
        ports.append({
            "device": port.device,
            "description": port.description or "",
            "manufacturer": port.manufacturer or "",
        })
    return ports


class PicoIce:
    def __init__(self, portName=None):
        if portName is None:
            portName = default_port()
        self.port_name = portName
        self.ser = serial.Serial(portName, 115200, timeout=0.5)

    def write(self, addr, data):
        to_send = struct.pack(">BBH", 0xAA, addr, data)
        self.ser.write(to_send)
        print(f"write send {to_send}")
        res = self.ser.read(2)
        print(f"write recv {res}")
        if len(res) != 2:
            raise RuntimeError(
                f"No valid UART write response on {self.port_name}. "
                "Check the selected COM port, the FPGA bitstream, and that the Pico-ICE USB-UART bridge is connected to the FPGA UART."
            )
        assert int(res[0]) == 0xAA, 'Invalid Write header'
        assert int(res[1]) == 0x0, 'Not successful response'
        return res

    def read(self, addr):
        to_send = struct.pack(">BB", 0x55, addr)
        self.ser.write(to_send)
        print(f"read send {to_send}")
        res = self.ser.read(3)
        print(f"read recv {res}")
        if len(res) != 3:
            raise RuntimeError(
                f"No valid UART read response on {self.port_name}. "
                "Check the selected COM port, the FPGA bitstream, and that the Pico-ICE default firmware USB-UART channel is the one you opened."
            )
        assert int(res[0]) == 0x55, 'Invalid read header'
        return struct.unpack(">H", res[1:])[0]

    def __del__(self):
        self.ser.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send UART register commands to the Pico-ICE FPGA design")
    parser.add_argument("--port", help="Serial port to use, for example COM5 on Windows or /dev/ttyACM1 on Linux")
    parser.add_argument("--list-ports", action="store_true", help="List detected serial ports and exit")
    args = parser.parse_args()

    if args.list_ports:
        for port in available_ports():
            print(f"{port['device']}: {port['description']} ({port['manufacturer']})")
        raise SystemExit(0)

    ice = PicoIce(args.port)
    print(ice.read(0x2))
    ice.write(0x0, 1)
    ice.write(0x2, 1)
    ice.write(0x4, 1)
