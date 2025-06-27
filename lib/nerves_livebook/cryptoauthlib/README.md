# Cryptoauthlib Bindings for Nerves Livebook

This module provides Elixir bindings for Microchip's cryptoauthlib library, enabling secure cryptographic operations with hardware security modules like the ATECC508A, ATECC608A, and ATECC608B.

## Features

- **Hardware Security**: Leverage dedicated cryptographic hardware for secure key storage and operations
- **ECDSA Operations**: Generate key pairs, sign messages, and verify signatures using NIST P-256 curve
- **Random Number Generation**: Hardware-based true random number generation
- **Secure Storage**: Store keys and data in tamper-resistant hardware
- **Device Configuration**: Configure and lock device zones for production use
- **Multiple Interfaces**: Support for I2C, SPI, and UART communication

## Supported Devices

- **ATECC508A**: ECC-based authentication with ECDSA and ECDH
- **ATECC608A**: Enhanced version with additional features and slots
- **ATECC608B**: Latest version with improved security features
- **ATSHA204A**: SHA-based authentication (legacy support)
- **ATSHA206A**: Enhanced SHA-based authentication

## Architecture

The bindings consist of several modules:

- `NervesLivebook.Cryptoauthlib` - Main API module with NIF functions
- `NervesLivebook.Cryptoauthlib.Config` - Device configuration and setup
- `NervesLivebook.Cryptoauthlib.Utils` - Utility functions for data formatting and operations

## Quick Start

### 1. Hardware Setup

Connect your cryptoauth device to your target hardware:

**I2C Connection (most common):**
```
Device Pin  | Raspberry Pi Pin
------------|------------------
VCC         | 3.3V (Pin 1)
GND         | Ground (Pin 6)
SDA         | GPIO 2 (Pin 3)
SCL         | GPIO 3 (Pin 5)
```

**Enable I2C in your Nerves configuration:**
```elixir
# config/target.exs
config :nerves_system_rpi4, :kernel_modules, ["i2c-dev"]
```

### 2. Basic Usage

```elixir
# Initialize the device
{:ok, device} = NervesLivebook.Cryptoauthlib.init()

# Get device information
{:ok, info} = NervesLivebook.Cryptoauthlib.get_info(device)
IO.inspect(info)
# %{
#   device_type: "ATECC608A",
#   serial_number: "0123456789ABCDEF",
#   config_locked: false,
#   data_locked: false
# }

# Generate a random number
{:ok, random_bytes} = NervesLivebook.Cryptoauthlib.random(device, 32)

# Generate a key pair in slot 0
{:ok, public_key} = NervesLivebook.Cryptoauthlib.genkey(device, 0)

# Sign a message
message = "Hello, secure world!"
digest = :crypto.hash(:sha256, message)
{:ok, signature} = NervesLivebook.Cryptoauthlib.sign(device, 0, digest)

# Verify the signature
{:ok, true} = NervesLivebook.Cryptoauthlib.verify(device, 0, digest, signature)

# Clean up
:ok = NervesLivebook.Cryptoauthlib.release(device)
```

### 3. Advanced Configuration

```elixir
alias NervesLivebook.Cryptoauthlib.Config

# Create a custom I2C configuration
config = Config.i2c(:atecc608a, 0x61, 
  bus: 1, 
  baud_rate: 400_000,
  wake_delay: 1000
)

# Validate the configuration
:ok = Config.validate(config)

# Get slot information for the device
slot_info = Config.slot_info(:atecc608a)
IO.inspect(slot_info)
# %{
#   total_slots: 16,
#   key_slots: [0, 1, 2, 3, 4, 5, 6, 7],
#   data_slots: [8, 9, 10, 11, 12, 13, 14, 15],
#   slot_size: 32
# }
```

### 4. Certificate Operations

```elixir
alias NervesLivebook.Cryptoauthlib.Utils

# Generate a key pair for certificate use
{:ok, device} = NervesLivebook.Cryptoauthlib.init()
{:ok, public_key} = NervesLivebook.Cryptoauthlib.genkey(device, 0)

# Format the public key for certificate generation
hex_key = Utils.format_public_key(public_key, :hex)
IO.puts("Public Key: #{hex_key}")

# Create a CSR template
subject = [
  common_name: "device-#{System.get_env("NERVES_SERIAL", "unknown")}",
  organization: "My IoT Company",
  country: "US"
]

{:ok, csr_template} = Utils.generate_csr_template(public_key, subject)
```

## Device Provisioning Workflow

### 1. Development Phase (Unlocked Device)

```elixir
{:ok, device} = NervesLivebook.Cryptoauthlib.init()

# Check lock status
{:ok, config_locked} = NervesLivebook.Cryptoauthlib.is_locked(device, :config)
{:ok, data_locked} = NervesLivebook.Cryptoauthlib.is_locked(device, :data)

if not config_locked do
  # Configure device slots, key policies, etc.
  # Write configuration data
  config_data = <<0x01, 0x23, 0x45, 0x67>>  # Example config
  :ok = NervesLivebook.Cryptoauthlib.write(device, :config, 0, 16, config_data)
end

if not data_locked do
  # Write initial data, certificates, etc.
  cert_data = File.read!("device_cert.der")
  :ok = NervesLivebook.Cryptoauthlib.write(device, :data, 10, 0, cert_data)
end
```

### 2. Production Phase (Lock Device)

**⚠️ WARNING: Locking is irreversible! Test thoroughly before locking.**

```elixir
{:ok, device} = NervesLivebook.Cryptoauthlib.init()

# Final verification before locking
{:ok, config_data} = NervesLivebook.Cryptoauthlib.read(device, :config, 0, 0, 128)
:ok = NervesLivebook.Cryptoauthlib.Utils.verify_config_integrity(config_data)

# Lock configuration zone
:ok = NervesLivebook.Cryptoauthlib.lock(device, :config)

# Lock data zone
:ok = NervesLivebook.Cryptoauthlib.lock(device, :data)

# Verify locks
{:ok, true} = NervesLivebook.Cryptoauthlib.is_locked(device, :config)
{:ok, true} = NervesLivebook.Cryptoauthlib.is_locked(device, :data)
```

## Error Handling

The library uses standard Elixir error patterns:

```elixir
case NervesLivebook.Cryptoauthlib.init() do
  {:ok, device} ->
    # Success - use device
    perform_crypto_operations(device)
    
  {:error, :device_not_found} ->
    Logger.error("Cryptoauth device not found - check wiring")
    
  {:error, :comm_fail} ->
    Logger.error("Communication failed - check I2C/SPI configuration")
    
  {:error, reason} ->
    Logger.error("Device initialization failed: #{inspect(reason)}")
end
```

Common error codes:
- `:device_not_found` - Hardware not detected
- `:comm_fail` - Communication timeout or error
- `:invalid_param` - Invalid slot number, data length, etc.
- `:device_error` - Hardware or firmware error
- `:timeout` - Operation timeout

## Security Considerations

1. **Key Management**: Private keys never leave the secure element
2. **Slot Configuration**: Configure key policies before locking
3. **Physical Security**: Protect the device from physical tampering
4. **Communication Security**: Use secure channels for sensitive operations
5. **Production Locking**: Always lock devices in production environments

## Troubleshooting

### Device Not Found
```bash
# Check I2C devices (on target)
i2cdetect -y 1

# Expected output should show device at 0x60 or configured address
#      0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
# 60: 60 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
```

### Communication Errors
```elixir
# Try different baud rates
config = Config.i2c(:atecc608a, 0x60, baud_rate: 100_000)  # Slower
config = Config.i2c(:atecc608a, 0x60, wake_delay: 2500)    # Longer wake
```

### Build Issues
```bash
# Install cryptoauthlib dependencies
make deps

# Clean and rebuild
make clean
mix compile
```

## Implementation Status

This is scaffolding code. To complete the implementation:

1. **Install Cryptoauthlib**: Download and build the actual cryptoauthlib C library
2. **Update C Code**: Replace placeholder code with actual cryptoauthlib API calls
3. **Device Tree**: Configure I2C/SPI device tree overlays for your hardware
4. **Testing**: Test with real hardware and various device configurations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This code is licensed under the Apache 2.0 License. See the LICENSE file for details.

The cryptoauthlib library is subject to its own license terms.

## Resources

- [Cryptoauthlib GitHub](https://github.com/MicrochipTech/cryptoauthlib)
- [ATECC608A Datasheet](https://www.microchip.com/en-us/product/ATECC608A)
- [Nerves Documentation](https://hexdocs.pm/nerves/getting-started.html)
- [I2C Configuration for Raspberry Pi](https://www.raspberrypi.org/documentation/configuration/device-tree.md)