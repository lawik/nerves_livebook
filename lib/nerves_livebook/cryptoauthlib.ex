defmodule NervesLivebook.Cryptoauthlib do
  @moduledoc """
  Elixir bindings for the cryptoauthlib library.

  This module provides a high-level interface to cryptographic operations
  using Microchip's cryptoauthlib library through NIFs (Native Implemented Functions).

  The cryptoauthlib library supports various cryptographic authentication devices
  including ATECC508A, ATECC608A, ATECC608B, and others.

  ## Features

  * Device initialization and configuration
  * Key generation and management
  * Digital signature operations (ECDSA)
  * Random number generation
  * Secure key storage
  * Certificate operations
  * Device locking and configuration

  ## Usage

  ```elixir
  # Initialize the device
  {:ok, device} = NervesLivebook.Cryptoauthlib.init()

  # Generate a random number
  {:ok, random_bytes} = NervesLivebook.Cryptoauthlib.random(device, 32)

  # Generate a key pair
  {:ok, public_key} = NervesLivebook.Cryptoauthlib.genkey(device, 0)
  ```

  ## Error Handling

  Most functions return `{:ok, result}` on success or `{:error, reason}` on failure.
  The reason will be an atom representing the specific error condition.
  """

  @on_load :load_nif

  @doc false
  def load_nif do
    nif_path = :filename.join(:code.priv_dir(:nerves_livebook), ~c"cryptoauthlib_nif")
    :erlang.load_nif(nif_path, 0)
  end

  @doc """
  Initialize the cryptoauth device.

  Returns `{:ok, device_handle}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.init()
      {:ok, #Reference<0.123456789.0>}

  """
  def init do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Release resources associated with a device handle.

  ## Parameters

  * `device` - Device handle returned from `init/0`

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.release(device)
      :ok

  """
  def release(_device) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Get device information and configuration.

  ## Parameters

  * `device` - Device handle returned from `init/0`

  Returns `{:ok, info_map}` with device information or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.get_info(device)
      {:ok, %{device_type: "ATECC608A", serial_number: <<...>>, ...}}

  """
  def get_info(_device) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Generate a random number using the device's hardware random number generator.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `length` - Number of random bytes to generate (max 32)

  Returns `{:ok, random_bytes}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.random(device, 16)
      {:ok, <<0x12, 0x34, 0x56, ...>>}

  """
  def random(_device, _length) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Generate a new ECC private key and return the corresponding public key.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `slot` - Key slot number (0-15 depending on device)

  Returns `{:ok, public_key}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.genkey(device, 0)
      {:ok, <<0x04, ...>>}  # 64-byte uncompressed public key

  """
  def genkey(_device, _slot) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Get the public key from a specific slot.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `slot` - Key slot number (0-15 depending on device)

  Returns `{:ok, public_key}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.get_pubkey(device, 0)
      {:ok, <<0x04, ...>>}  # 64-byte uncompressed public key

  """
  def get_pubkey(_device, _slot) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Sign a message digest using the private key in the specified slot.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `slot` - Key slot number containing the private key
  * `digest` - 32-byte SHA-256 digest to sign

  Returns `{:ok, signature}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> digest = :crypto.hash(:sha256, "Hello, World!")
      iex> NervesLivebook.Cryptoauthlib.sign(device, 0, digest)
      {:ok, <<...>>}  # 64-byte signature

  """
  def sign(_device, _slot, _digest) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Verify a signature using the public key in the specified slot.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `slot` - Key slot number containing the public key
  * `digest` - 32-byte SHA-256 digest that was signed
  * `signature` - 64-byte signature to verify

  Returns `{:ok, true}`, `{:ok, false}`, or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> digest = :crypto.hash(:sha256, "Hello, World!")
      iex> {:ok, signature} = NervesLivebook.Cryptoauthlib.sign(device, 0, digest)
      iex> NervesLivebook.Cryptoauthlib.verify(device, 0, digest, signature)
      {:ok, true}

  """
  def verify(_device, _slot, _digest, _signature) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Read data from the specified zone and address.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `zone` - Zone to read from (:config, :otp, :data)
  * `slot` - Slot number (for data zone) or 0 (for config/otp zones)
  * `offset` - Byte offset within the zone/slot
  * `length` - Number of bytes to read

  Returns `{:ok, data}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.read(device, :config, 0, 0, 4)
      {:ok, <<0x01, 0x23, 0x45, 0x67>>}

  """
  def read(_device, _zone, _slot, _offset, _length) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Write data to the specified zone and address.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `zone` - Zone to write to (:config, :otp, :data)
  * `slot` - Slot number (for data zone) or 0 (for config/otp zones)
  * `offset` - Byte offset within the zone/slot
  * `data` - Binary data to write

  Returns `:ok` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.write(device, :data, 8, 0, <<1, 2, 3, 4>>)
      :ok

  """
  def write(_device, _zone, _slot, _offset, _data) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Lock the specified zone to prevent further writes.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `zone` - Zone to lock (:config, :data)

  Returns `:ok` or `{:error, reason}`.

  **Warning**: This operation is irreversible!

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.lock(device, :config)
      :ok

  """
  def lock(_device, _zone) do
    :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Get the lock status of the specified zone.

  ## Parameters

  * `device` - Device handle returned from `init/0`
  * `zone` - Zone to check (:config, :data)

  Returns `{:ok, locked?}` or `{:error, reason}`.

  ## Examples

      iex> {:ok, device} = NervesLivebook.Cryptoauthlib.init()
      iex> NervesLivebook.Cryptoauthlib.is_locked(device, :config)
      {:ok, false}

  """
  def is_locked(_device, _zone) do
    :erlang.nif_error(:nif_not_loaded)
  end
end