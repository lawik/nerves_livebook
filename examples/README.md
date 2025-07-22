# CryptoAuth Library Examples

This directory contains examples demonstrating how to use the NervesLivebook.Cryptoauthlib module with I2C-connected cryptographic authentication devices.

## Prerequisites

1. **Hardware Setup**
   - CryptoAuth device (ATECC508A, ATECC608A, ATECC608B, etc.)
   - Connected via I2C to your system
   - Proper pull-up resistors on SDA/SCL lines (typically 4.7kΩ)

2. **Software Requirements**
   - Elixir/Erlang installed
   - NervesLivebook project compiled with cryptoauthlib NIF
   - I2C bus enabled on your system

3. **I2C Configuration**
   - Default device address: 0xC0 (7-bit: 0x60)
   - Default baud rate: 400kHz
   - Common I2C bus numbers: 0, 1, 2 (depends on your system)

## Examples

### basic_usage.exs

Comprehensive example demonstrating all major cryptoauth operations with I2C bus specification.

**Run with automatic bus detection:**
```bash
elixir basic_usage.exs
```

**Run with specific I2C bus:**
```bash
elixir basic_usage.exs 1    # Use I2C bus 1
elixir basic_usage.exs 0    # Use I2C bus 0
elixir basic_usage.exs 2    # Use I2C bus 2
```

**Features demonstrated:**
- Device initialization with I2C bus specification
- Device information retrieval
- Random number generation
- Key pair generation and retrieval
- Digital signature creation and verification
- Data zone reading
- Zone lock status checking

## Common I2C Bus Numbers

The I2C bus number depends on your hardware platform:

| Platform | Common I2C Buses | Notes |
|----------|------------------|-------|
| Raspberry Pi | 0, 1 | Bus 1 is typically exposed on GPIO pins |
| BeagleBone | 0, 1, 2 | Multiple I2C controllers available |
| Generic Linux | 0, 1, 2, ... | Check `/dev/i2c-*` devices |
| Nerves Devices | Varies | Check your target's configuration |

## Troubleshooting

### Device Not Found
If you get initialization errors:

1. **Check I2C bus availability:**
   ```bash
   ls /dev/i2c-*
   i2cdetect -l
   ```

2. **Scan for devices on the bus:**
   ```bash
   i2cdetect -y 1  # Replace 1 with your bus number
   ```
   You should see a device at address 0x60 (0xC0 in 8-bit format).

3. **Check connections:**
   - VCC: 3.3V or 5V (depending on device)
   - GND: Ground
   - SDA: I2C data line with pull-up resistor
   - SCL: I2C clock line with pull-up resistor

### Permission Issues
If you get permission denied errors:
```bash
sudo chmod 666 /dev/i2c-*
# Or add your user to the i2c group:
sudo usermod -a -G i2c $USER
```

### Wrong I2C Address
If the device uses a different I2C address, you'll need to modify the C code:
```c
device->cfg.atcai2c.address = 0xC2;  // Example for different address
```

## Device Configuration

The library uses these default I2C settings:
- **Interface**: I2C
- **Device Type**: ATECC608A (auto-detected)
- **I2C Address**: 0xC0 (8-bit) / 0x60 (7-bit)
- **Baud Rate**: 400kHz
- **Wake Delay**: 1500μs
- **RX Retries**: 20

## Security Considerations

1. **Private Keys**: Never extract private keys from the device
2. **Zone Locking**: Be careful with lock operations - they are irreversible
3. **Key Slots**: Different slots may have different access policies
4. **Production vs Development**: Use appropriate configurations for your use case

## Example Output

When running `basic_usage.exs`, you should see output like:

```
=== CryptoAuth Library I2C Example ===

Attempting to initialize device on I2C bus 0...
✗ Failed to initialize on I2C bus 0: :device_not_found

Attempting to initialize device on I2C bus 1...
✓ Successfully initialized device on I2C bus 1
  Demonstrating operations on I2C bus 1:
  ✓ Device info: %{device_type: "ATECC608A", ...}
  ✓ Generated 16 random bytes: A1B2C3D4E5F67890...
  ✓ Generated key pair in slot 0
    Public key: 04A1B2C3D4...
  ✓ Signed message: "Hello from I2C CryptoAuth device!"
    Signature: 1234567890ABCDEF...
  ✓ Signature verification passed
  ✓ Read config data: 01234567
✓ Released device resources
```

## Contributing

When adding new examples:
1. Document the I2C bus requirements
2. Include error handling for common issues
3. Demonstrate proper resource cleanup
4. Add clear usage instructions
5. Test on multiple I2C bus numbers when possible