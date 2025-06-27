defmodule NervesLivebook.Cryptoauthlib.Config do
  @moduledoc """
  Configuration module for Cryptoauthlib devices.

  This module provides functions to manage device configurations, including
  default configurations for common device types and utilities for creating
  custom configurations.

  ## Device Types

  Supported device types include:
  * ATECC508A
  * ATECC608A
  * ATECC608B
  * ATSHA204A
  * ATSHA206A

  ## Configuration Structure

  Device configurations are represented as maps with the following structure:

  ```elixir
  %{
    device_type: :atecc608a,
    interface: :i2c,
    interface_params: %{
      slave_address: 0x60,
      bus: 1,
      baud_rate: 100_000
    },
    wake_delay: 1500,
    rx_retries: 20
  }
  ```
  """

  @type device_type :: :atecc508a | :atecc608a | :atecc608b | :atsha204a | :atsha206a
  @type interface_type :: :i2c | :spi | :uart
  @type config :: %{
          device_type: device_type(),
          interface: interface_type(),
          interface_params: map(),
          wake_delay: non_neg_integer(),
          rx_retries: non_neg_integer()
        }

  @doc """
  Get the default configuration for a specific device type.

  ## Parameters

  * `device_type` - The type of device (:atecc508a, :atecc608a, etc.)
  * `opts` - Optional parameters to override defaults

  ## Options

  * `:slave_address` - I2C slave address (default varies by device)
  * `:bus` - I2C bus number (default 1)
  * `:baud_rate` - I2C baud rate (default 100_000)
  * `:wake_delay` - Wake delay in microseconds (default 1500)
  * `:rx_retries` - Number of receive retries (default 20)

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Config.default(:atecc608a)
      %{
        device_type: :atecc608a,
        interface: :i2c,
        interface_params: %{
          slave_address: 0x60,
          bus: 1,
          baud_rate: 100_000
        },
        wake_delay: 1500,
        rx_retries: 20
      }

      iex> NervesLivebook.Cryptoauthlib.Config.default(:atecc608a, slave_address: 0x61)
      %{
        device_type: :atecc608a,
        interface: :i2c,
        interface_params: %{
          slave_address: 0x61,
          bus: 1,
          baud_rate: 100_000
        },
        wake_delay: 1500,
        rx_retries: 20
      }

  """
  @spec default(device_type(), keyword()) :: config()
  def default(device_type, opts \\ []) do
    base_config = get_base_config(device_type)
    
    interface_params = Map.merge(base_config.interface_params, Enum.into(opts, %{}))
    
    base_config
    |> Map.put(:interface_params, interface_params)
    |> Map.merge(Enum.into(Keyword.drop(opts, [:slave_address, :bus, :baud_rate]), %{}))
  end

  @doc """
  Create a custom I2C configuration.

  ## Parameters

  * `device_type` - The type of device
  * `slave_address` - I2C slave address
  * `opts` - Additional options

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Config.i2c(:atecc608a, 0x60)
      %{device_type: :atecc608a, interface: :i2c, ...}

  """
  @spec i2c(device_type(), non_neg_integer(), keyword()) :: config()
  def i2c(device_type, slave_address, opts \\ []) do
    default_opts = [
      bus: 1,
      baud_rate: 100_000,
      wake_delay: 1500,
      rx_retries: 20
    ]

    merged_opts = Keyword.merge(default_opts, opts)

    %{
      device_type: device_type,
      interface: :i2c,
      interface_params: %{
        slave_address: slave_address,
        bus: merged_opts[:bus],
        baud_rate: merged_opts[:baud_rate]
      },
      wake_delay: merged_opts[:wake_delay],
      rx_retries: merged_opts[:rx_retries]
    }
  end

  @doc """
  Create a custom SPI configuration.

  ## Parameters

  * `device_type` - The type of device
  * `opts` - SPI configuration options

  ## Options

  * `:bus` - SPI bus number (default 0)
  * `:device` - SPI device number (default 0)
  * `:speed_hz` - SPI clock speed (default 1_000_000)
  * `:mode` - SPI mode (default 0)

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Config.spi(:atecc608a)
      %{device_type: :atecc608a, interface: :spi, ...}

  """
  @spec spi(device_type(), keyword()) :: config()
  def spi(device_type, opts \\ []) do
    default_opts = [
      bus: 0,
      device: 0,
      speed_hz: 1_000_000,
      mode: 0,
      wake_delay: 1500,
      rx_retries: 20
    ]

    merged_opts = Keyword.merge(default_opts, opts)

    %{
      device_type: device_type,
      interface: :spi,
      interface_params: %{
        bus: merged_opts[:bus],
        device: merged_opts[:device],
        speed_hz: merged_opts[:speed_hz],
        mode: merged_opts[:mode]
      },
      wake_delay: merged_opts[:wake_delay],
      rx_retries: merged_opts[:rx_retries]
    }
  end

  @doc """
  Validate a configuration map.

  Returns `:ok` if the configuration is valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> config = NervesLivebook.Cryptoauthlib.Config.default(:atecc608a)
      iex> NervesLivebook.Cryptoauthlib.Config.validate(config)
      :ok

      iex> NervesLivebook.Cryptoauthlib.Config.validate(%{invalid: :config})
      {:error, :invalid_device_type}

  """
  @spec validate(map()) :: :ok | {:error, atom()}
  def validate(%{device_type: device_type} = config) when device_type in [:atecc508a, :atecc608a, :atecc608b, :atsha204a, :atsha206a] do
    with :ok <- validate_interface(config),
         :ok <- validate_interface_params(config),
         :ok <- validate_timings(config) do
      :ok
    end
  end

  def validate(_config) do
    {:error, :invalid_device_type}
  end

  @doc """
  Get the slot configuration for a device type.

  Returns information about the available slots and their capabilities.

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Config.slot_info(:atecc608a)
      %{
        total_slots: 16,
        key_slots: [0, 1, 2, 3, 4, 5, 6, 7],
        data_slots: [8, 9, 10, 11, 12, 13, 14, 15],
        slot_size: 32
      }

  """
  @spec slot_info(device_type()) :: map()
  def slot_info(:atecc508a) do
    %{
      total_slots: 16,
      key_slots: [0, 1, 2, 3, 4, 5, 6, 7],
      data_slots: [8, 9, 10, 11, 12, 13, 14, 15],
      slot_size: 32
    }
  end

  def slot_info(:atecc608a) do
    %{
      total_slots: 16,
      key_slots: [0, 1, 2, 3, 4, 5, 6, 7],
      data_slots: [8, 9, 10, 11, 12, 13, 14, 15],
      slot_size: 32
    }
  end

  def slot_info(:atecc608b) do
    %{
      total_slots: 16,
      key_slots: [0, 1, 2, 3, 4, 5, 6, 7],
      data_slots: [8, 9, 10, 11, 12, 13, 14, 15],
      slot_size: 32
    }
  end

  def slot_info(:atsha204a) do
    %{
      total_slots: 16,
      key_slots: [],
      data_slots: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      slot_size: 32
    }
  end

  def slot_info(:atsha206a) do
    %{
      total_slots: 16,
      key_slots: [],
      data_slots: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      slot_size: 32
    }
  end

  # Private functions

  defp get_base_config(:atecc508a) do
    %{
      device_type: :atecc508a,
      interface: :i2c,
      interface_params: %{
        slave_address: 0x60,
        bus: 1,
        baud_rate: 100_000
      },
      wake_delay: 1500,
      rx_retries: 20
    }
  end

  defp get_base_config(:atecc608a) do
    %{
      device_type: :atecc608a,
      interface: :i2c,
      interface_params: %{
        slave_address: 0x60,
        bus: 1,
        baud_rate: 100_000
      },
      wake_delay: 1500,
      rx_retries: 20
    }
  end

  defp get_base_config(:atecc608b) do
    %{
      device_type: :atecc608b,
      interface: :i2c,
      interface_params: %{
        slave_address: 0x60,
        bus: 1,
        baud_rate: 100_000
      },
      wake_delay: 1500,
      rx_retries: 20
    }
  end

  defp get_base_config(:atsha204a) do
    %{
      device_type: :atsha204a,
      interface: :i2c,
      interface_params: %{
        slave_address: 0x64,
        bus: 1,
        baud_rate: 100_000
      },
      wake_delay: 2500,
      rx_retries: 20
    }
  end

  defp get_base_config(:atsha206a) do
    %{
      device_type: :atsha206a,
      interface: :i2c,
      interface_params: %{
        slave_address: 0x64,
        bus: 1,
        baud_rate: 100_000
      },
      wake_delay: 2500,
      rx_retries: 20
    }
  end

  defp validate_interface(%{interface: interface}) when interface in [:i2c, :spi, :uart] do
    :ok
  end

  defp validate_interface(_config) do
    {:error, :invalid_interface}
  end

  defp validate_interface_params(%{interface: :i2c, interface_params: params}) do
    required_keys = [:slave_address, :bus, :baud_rate]
    if Enum.all?(required_keys, &Map.has_key?(params, &1)) do
      :ok
    else
      {:error, :missing_i2c_params}
    end
  end

  defp validate_interface_params(%{interface: :spi, interface_params: params}) do
    required_keys = [:bus, :device, :speed_hz, :mode]
    if Enum.all?(required_keys, &Map.has_key?(params, &1)) do
      :ok
    else
      {:error, :missing_spi_params}
    end
  end

  defp validate_interface_params(_config) do
    {:error, :invalid_interface_params}
  end

  defp validate_timings(%{wake_delay: wake_delay, rx_retries: rx_retries}) 
       when is_integer(wake_delay) and wake_delay >= 0 and 
            is_integer(rx_retries) and rx_retries >= 0 do
    :ok
  end

  defp validate_timings(_config) do
    {:error, :invalid_timings}
  end
end