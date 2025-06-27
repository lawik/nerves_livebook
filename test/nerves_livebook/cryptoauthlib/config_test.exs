defmodule NervesLivebook.Cryptoauthlib.ConfigTest do
  use ExUnit.Case, async: true
  doctest NervesLivebook.Cryptoauthlib.Config

  alias NervesLivebook.Cryptoauthlib.Config

  describe "default/2" do
    test "returns default configuration for ATECC608A" do
      config = Config.default(:atecc608a)

      assert config.device_type == :atecc608a
      assert config.interface == :i2c
      assert config.interface_params.slave_address == 0x60
      assert config.interface_params.bus == 1
      assert config.interface_params.baud_rate == 100_000
      assert config.wake_delay == 1500
      assert config.rx_retries == 20
    end

    test "returns default configuration for ATECC508A" do
      config = Config.default(:atecc508a)

      assert config.device_type == :atecc508a
      assert config.interface == :i2c
      assert config.interface_params.slave_address == 0x60
      assert config.interface_params.bus == 1
      assert config.interface_params.baud_rate == 100_000
      assert config.wake_delay == 1500
      assert config.rx_retries == 20
    end

    test "returns default configuration for ATSHA204A with different defaults" do
      config = Config.default(:atsha204a)

      assert config.device_type == :atsha204a
      assert config.interface == :i2c
      assert config.interface_params.slave_address == 0x64
      assert config.interface_params.bus == 1
      assert config.interface_params.baud_rate == 100_000
      assert config.wake_delay == 2500
      assert config.rx_retries == 20
    end

    test "allows overriding interface parameters" do
      config = Config.default(:atecc608a, slave_address: 0x61, bus: 2)

      assert config.interface_params.slave_address == 0x61
      assert config.interface_params.bus == 2
      assert config.interface_params.baud_rate == 100_000  # unchanged
    end

    test "allows overriding timing parameters" do
      config = Config.default(:atecc608a, wake_delay: 2000, rx_retries: 10)

      assert config.wake_delay == 2000
      assert config.rx_retries == 10
      assert config.interface_params.slave_address == 0x60  # unchanged
    end
  end

  describe "i2c/3" do
    test "creates I2C configuration with default options" do
      config = Config.i2c(:atecc608a, 0x61)

      assert config.device_type == :atecc608a
      assert config.interface == :i2c
      assert config.interface_params.slave_address == 0x61
      assert config.interface_params.bus == 1
      assert config.interface_params.baud_rate == 100_000
      assert config.wake_delay == 1500
      assert config.rx_retries == 20
    end

    test "creates I2C configuration with custom options" do
      opts = [bus: 2, baud_rate: 400_000, wake_delay: 1000, rx_retries: 30]
      config = Config.i2c(:atecc508a, 0x62, opts)

      assert config.device_type == :atecc508a
      assert config.interface == :i2c
      assert config.interface_params.slave_address == 0x62
      assert config.interface_params.bus == 2
      assert config.interface_params.baud_rate == 400_000
      assert config.wake_delay == 1000
      assert config.rx_retries == 30
    end
  end

  describe "spi/2" do
    test "creates SPI configuration with default options" do
      config = Config.spi(:atecc608a)

      assert config.device_type == :atecc608a
      assert config.interface == :spi
      assert config.interface_params.bus == 0
      assert config.interface_params.device == 0
      assert config.interface_params.speed_hz == 1_000_000
      assert config.interface_params.mode == 0
      assert config.wake_delay == 1500
      assert config.rx_retries == 20
    end

    test "creates SPI configuration with custom options" do
      opts = [bus: 1, device: 1, speed_hz: 2_000_000, mode: 1, wake_delay: 2000]
      config = Config.spi(:atecc608b, opts)

      assert config.device_type == :atecc608b
      assert config.interface == :spi
      assert config.interface_params.bus == 1
      assert config.interface_params.device == 1
      assert config.interface_params.speed_hz == 2_000_000
      assert config.interface_params.mode == 1
      assert config.wake_delay == 2000
      assert config.rx_retries == 20
    end
  end

  describe "validate/1" do
    test "validates correct I2C configuration" do
      config = Config.default(:atecc608a)
      assert Config.validate(config) == :ok
    end

    test "validates correct SPI configuration" do
      config = Config.spi(:atecc608a)
      assert Config.validate(config) == :ok
    end

    test "rejects configuration with invalid device type" do
      config = %{device_type: :invalid_device}
      assert Config.validate(config) == {:error, :invalid_device_type}
    end

    test "rejects configuration without device type" do
      config = %{interface: :i2c}
      assert Config.validate(config) == {:error, :invalid_device_type}
    end

    test "rejects configuration with invalid interface" do
      config = %{
        device_type: :atecc608a,
        interface: :invalid_interface,
        interface_params: %{},
        wake_delay: 1500,
        rx_retries: 20
      }
      assert Config.validate(config) == {:error, :invalid_interface}
    end

    test "rejects I2C configuration with missing parameters" do
      config = %{
        device_type: :atecc608a,
        interface: :i2c,
        interface_params: %{slave_address: 0x60},  # missing bus and baud_rate
        wake_delay: 1500,
        rx_retries: 20
      }
      assert Config.validate(config) == {:error, :missing_i2c_params}
    end

    test "rejects SPI configuration with missing parameters" do
      config = %{
        device_type: :atecc608a,
        interface: :spi,
        interface_params: %{bus: 0},  # missing device, speed_hz, mode
        wake_delay: 1500,
        rx_retries: 20
      }
      assert Config.validate(config) == {:error, :missing_spi_params}
    end

    test "rejects configuration with invalid timing parameters" do
      config = %{
        device_type: :atecc608a,
        interface: :i2c,
        interface_params: %{slave_address: 0x60, bus: 1, baud_rate: 100_000},
        wake_delay: -1,  # invalid
        rx_retries: 20
      }
      assert Config.validate(config) == {:error, :invalid_timings}

      config = %{
        device_type: :atecc608a,
        interface: :i2c,
        interface_params: %{slave_address: 0x60, bus: 1, baud_rate: 100_000},
        wake_delay: 1500,
        rx_retries: "invalid"  # invalid type
      }
      assert Config.validate(config) == {:error, :invalid_timings}
    end
  end

  describe "slot_info/1" do
    test "returns correct slot info for ATECC508A" do
      info = Config.slot_info(:atecc508a)

      assert info.total_slots == 16
      assert info.key_slots == [0, 1, 2, 3, 4, 5, 6, 7]
      assert info.data_slots == [8, 9, 10, 11, 12, 13, 14, 15]
      assert info.slot_size == 32
    end

    test "returns correct slot info for ATECC608A" do
      info = Config.slot_info(:atecc608a)

      assert info.total_slots == 16
      assert info.key_slots == [0, 1, 2, 3, 4, 5, 6, 7]
      assert info.data_slots == [8, 9, 10, 11, 12, 13, 14, 15]
      assert info.slot_size == 32
    end

    test "returns correct slot info for ATECC608B" do
      info = Config.slot_info(:atecc608b)

      assert info.total_slots == 16
      assert info.key_slots == [0, 1, 2, 3, 4, 5, 6, 7]
      assert info.data_slots == [8, 9, 10, 11, 12, 13, 14, 15]
      assert info.slot_size == 32
    end

    test "returns correct slot info for ATSHA204A (no key slots)" do
      info = Config.slot_info(:atsha204a)

      assert info.total_slots == 16
      assert info.key_slots == []
      assert info.data_slots == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      assert info.slot_size == 32
    end

    test "returns correct slot info for ATSHA206A (no key slots)" do
      info = Config.slot_info(:atsha206a)

      assert info.total_slots == 16
      assert info.key_slots == []
      assert info.data_slots == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      assert info.slot_size == 32
    end
  end

  describe "device type variations" do
    test "all supported device types work with default/1" do
      supported_devices = [:atecc508a, :atecc608a, :atecc608b, :atsha204a, :atsha206a]

      for device_type <- supported_devices do
        config = Config.default(device_type)
        assert config.device_type == device_type
        assert Config.validate(config) == :ok
      end
    end

    test "all supported device types work with i2c/2" do
      supported_devices = [:atecc508a, :atecc608a, :atecc608b, :atsha204a, :atsha206a]

      for device_type <- supported_devices do
        config = Config.i2c(device_type, 0x60)
        assert config.device_type == device_type
        assert config.interface == :i2c
        assert Config.validate(config) == :ok
      end
    end

    test "all supported device types work with spi/2" do
      supported_devices = [:atecc508a, :atecc608a, :atecc608b, :atsha204a, :atsha206a]

      for device_type <- supported_devices do
        config = Config.spi(device_type)
        assert config.device_type == device_type
        assert config.interface == :spi
        assert Config.validate(config) == :ok
      end
    end

    test "all supported device types have slot info" do
      supported_devices = [:atecc508a, :atecc608a, :atecc608b, :atsha204a, :atsha206a]

      for device_type <- supported_devices do
        info = Config.slot_info(device_type)
        assert is_map(info)
        assert Map.has_key?(info, :total_slots)
        assert Map.has_key?(info, :key_slots)
        assert Map.has_key?(info, :data_slots)
        assert Map.has_key?(info, :slot_size)
      end
    end
  end

  describe "configuration patterns" do
    test "common I2C configurations" do
      # Standard ATECC608A on Raspberry Pi
      config = Config.i2c(:atecc608a, 0x60, bus: 1, baud_rate: 100_000)
      assert Config.validate(config) == :ok

      # High-speed I2C
      config = Config.i2c(:atecc608a, 0x60, bus: 1, baud_rate: 400_000)
      assert Config.validate(config) == :ok

      # Alternative I2C address
      config = Config.i2c(:atecc608a, 0x61, bus: 1, baud_rate: 100_000)
      assert Config.validate(config) == :ok
    end

    test "common SPI configurations" do
      # Standard SPI configuration
      config = Config.spi(:atecc608a, bus: 0, device: 0, speed_hz: 1_000_000, mode: 0)
      assert Config.validate(config) == :ok

      # High-speed SPI
      config = Config.spi(:atecc608a, bus: 0, device: 0, speed_hz: 5_000_000, mode: 0)
      assert Config.validate(config) == :ok

      # Alternative SPI bus
      config = Config.spi(:atecc608a, bus: 1, device: 0, speed_hz: 1_000_000, mode: 0)
      assert Config.validate(config) == :ok
    end
  end
end