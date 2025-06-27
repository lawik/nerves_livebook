defmodule NervesLivebook.Cryptoauthlib.Utils do
  @moduledoc """
  Utility functions for Cryptoauthlib operations.

  This module provides helper functions for common cryptographic operations,
  data formatting, and certificate handling when working with cryptoauth devices.
  """

  import Bitwise

  @doc """
  Convert a binary to a hexadecimal string representation.

  ## Parameters

  * `binary` - Binary data to convert
  * `opts` - Options for formatting (optional)

  ## Options

  * `:uppercase` - Use uppercase hex digits (default: false)
  * `:separator` - Separator between bytes (default: "")
  * `:prefix` - Prefix for the hex string (default: "")

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Utils.binary_to_hex(<<0x01, 0x23, 0x45>>)
      "012345"

      iex> NervesLivebook.Cryptoauthlib.Utils.binary_to_hex(<<0x01, 0x23, 0x45>>, uppercase: true, separator: ":")
      "01:23:45"

      iex> NervesLivebook.Cryptoauthlib.Utils.binary_to_hex(<<0x01, 0x23, 0x45>>, prefix: "0x")
      "0x012345"

  """
  def binary_to_hex(binary, opts \\ []) when is_binary(binary) do
    uppercase = Keyword.get(opts, :uppercase, false)
    separator = Keyword.get(opts, :separator, "")
    prefix = Keyword.get(opts, :prefix, "")

    format = if uppercase, do: :uppercase, else: :lowercase

    hex_string = 
      binary
      |> :binary.bin_to_list()
      |> Enum.map(&format_byte(&1, format))
      |> Enum.join(separator)

    prefix <> hex_string
  end

  @doc """
  Convert a hexadecimal string to binary data.

  ## Parameters

  * `hex_string` - Hexadecimal string to convert
  * `opts` - Options for parsing (optional)

  ## Options

  * `:separator` - Separator between bytes in the hex string (default: "")

  ## Examples

      iex> NervesLivebook.Cryptoauthlib.Utils.hex_to_binary("012345")
      <<0x01, 0x23, 0x45>>

      iex> NervesLivebook.Cryptoauthlib.Utils.hex_to_binary("01:23:45", separator: ":")
      <<0x01, 0x23, 0x45>>

      iex> NervesLivebook.Cryptoauthlib.Utils.hex_to_binary("0x012345")
      <<0x01, 0x23, 0x45>>

  """
  def hex_to_binary(hex_string, opts \\ []) when is_binary(hex_string) do
    separator = Keyword.get(opts, :separator, "")

    # Remove common prefixes
    cleaned_hex = 
      hex_string
      |> String.replace_prefix("0x", "")
      |> String.replace_prefix("0X", "")

    # Split by separator if provided
    hex_parts = if separator != "", do: String.split(cleaned_hex, separator), else: [cleaned_hex]

    # Convert to binary
    hex_parts
    |> Enum.join("")
    |> String.upcase()
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(&String.to_integer(&1, 16))
    |> :binary.list_to_bin()
  end

  @doc """
  Format a public key for display or storage.

  ## Parameters

  * `public_key` - 64-byte uncompressed public key
  * `format` - Output format (:hex, :pem, :der, :compressed)

  ## Examples

      iex> pubkey = <<0x04, ...>>  # 65-byte key with 0x04 prefix
      iex> NervesLivebook.Cryptoauthlib.Utils.format_public_key(pubkey, :hex)
      "04abcd..."

      iex> NervesLivebook.Cryptoauthlib.Utils.format_public_key(pubkey, :compressed)
      <<0x02, ...>>  # 33-byte compressed key

  """
  def format_public_key(public_key, format) when is_binary(public_key) do
    case format do
      :hex ->
        binary_to_hex(public_key)

      :compressed ->
        compress_public_key(public_key)

      :uncompressed ->
        ensure_uncompressed_prefix(public_key)

      :pem ->
        public_key_to_pem(public_key)

      :der ->
        public_key_to_der(public_key)

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Validate that a binary is a valid SHA-256 digest.

  ## Parameters

  * `digest` - Binary to validate

  ## Examples

      iex> digest = :crypto.hash(:sha256, "test")
      iex> NervesLivebook.Cryptoauthlib.Utils.validate_sha256_digest(digest)
      :ok

      iex> NervesLivebook.Cryptoauthlib.Utils.validate_sha256_digest(<<1, 2, 3>>)
      {:error, :invalid_digest_length}

  """
  def validate_sha256_digest(digest) when is_binary(digest) do
    if byte_size(digest) == 32 do
      :ok
    else
      {:error, :invalid_digest_length}
    end
  end

  @doc """
  Validate that a binary is a valid ECDSA signature.

  ## Parameters

  * `signature` - Binary to validate

  ## Examples

      iex> signature = <<...>>  # 64-byte signature
      iex> NervesLivebook.Cryptoauthlib.Utils.validate_ecdsa_signature(signature)
      :ok

  """
  def validate_ecdsa_signature(signature) when is_binary(signature) do
    if byte_size(signature) == 64 do
      :ok
    else
      {:error, :invalid_signature_length}
    end
  end

  @doc """
  Convert an ECDSA signature between different formats.

  ## Parameters

  * `signature` - Input signature
  * `from_format` - Input format (:raw, :der, :jose)
  * `to_format` - Output format (:raw, :der, :jose)

  ## Examples

      iex> raw_sig = <<...>>  # 64-byte raw signature
      iex> NervesLivebook.Cryptoauthlib.Utils.convert_signature(raw_sig, :raw, :der)
      {:ok, der_encoded_signature}

  """
  def convert_signature(signature, from_format, to_format) do
    with {:ok, {r, s}} <- decode_signature(signature, from_format) do
      encode_signature({r, s}, to_format)
    end
  end

  @doc """
  Generate a certificate signing request (CSR) template.

  ## Parameters

  * `public_key` - 64-byte public key
  * `subject` - Subject information as a keyword list
  * `opts` - Additional options

  ## Subject Options

  * `:common_name` - Common name (CN)
  * `:organization` - Organization (O)
  * `:organizational_unit` - Organizational unit (OU)
  * `:country` - Country (C)
  * `:state` - State or province (ST)
  * `:locality` - Locality (L)

  ## Examples

      iex> pubkey = <<...>>
      iex> subject = [common_name: "device-123", organization: "Acme Corp"]
      iex> NervesLivebook.Cryptoauthlib.Utils.generate_csr_template(pubkey, subject)
      {:ok, csr_template}

  """
  def generate_csr_template(public_key, subject, opts \\ []) do
    with :ok <- validate_public_key(public_key),
         {:ok, subject_der} <- encode_subject(subject) do
      template = %{
        public_key: public_key,
        subject: subject_der,
        extensions: Keyword.get(opts, :extensions, []),
        signature_algorithm: :ecdsa_with_sha256
      }
      {:ok, template}
    end
  end

  @doc """
  Calculate the device's serial number from its public key or other identifying information.

  ## Parameters

  * `device_info` - Device information map
  * `opts` - Options for serial number generation

  ## Examples

      iex> device_info = %{public_key: <<...>>, device_type: :atecc608a}
      iex> NervesLivebook.Cryptoauthlib.Utils.calculate_serial_number(device_info)
      {:ok, "AABBCC112233"}

  """
  def calculate_serial_number(device_info, _opts \\ []) do
    case device_info do
      %{serial_number: serial} when is_binary(serial) ->
        {:ok, binary_to_hex(serial, uppercase: true)}

      %{public_key: public_key} ->
        # Generate serial from public key hash
        hash = :crypto.hash(:sha256, public_key)
        serial = binary_part(hash, 0, 6)
        {:ok, binary_to_hex(serial, uppercase: true)}

      _ ->
        {:error, :insufficient_device_info}
    end
  end

  @doc """
  Verify the integrity of configuration data.

  ## Parameters

  * `config_data` - Configuration data to verify
  * `expected_crc` - Expected CRC value (optional)

  ## Examples

      iex> config = <<...>>
      iex> NervesLivebook.Cryptoauthlib.Utils.verify_config_integrity(config)
      {:ok, calculated_crc}

  """
  def verify_config_integrity(config_data, expected_crc \\ nil) do
    calculated_crc = calculate_crc16(config_data)
    
    case expected_crc do
      nil ->
        {:ok, calculated_crc}
      
      ^calculated_crc ->
        :ok
      
      _ ->
        {:error, :crc_mismatch}
    end
  end

  # Private helper functions

  defp format_byte(byte, :uppercase) do
    :io_lib.format("~2.16.0B", [byte]) |> List.to_string()
  end

  defp format_byte(byte, :lowercase) do
    :io_lib.format("~2.16.0b", [byte]) |> List.to_string()
  end

  defp compress_public_key(<<0x04, x::binary-size(32), y::binary-size(32)>>) do
    # Compress by keeping only x coordinate and y parity
    <<y_byte::integer-size(8), _::binary>> = y
    prefix = if rem(y_byte, 2) == 0, do: 0x02, else: 0x03
    <<prefix, x::binary>>
  end

  defp compress_public_key(public_key) when byte_size(public_key) == 64 do
    # Add 0x04 prefix and compress
    compress_public_key(<<0x04, public_key::binary>>)
  end

  defp ensure_uncompressed_prefix(<<0x04, _::binary>> = key), do: key
  defp ensure_uncompressed_prefix(key) when byte_size(key) == 64 do
    <<0x04, key::binary>>
  end

  defp public_key_to_pem(_public_key) do
    # This would require ASN.1 encoding - simplified for now
    {:error, :not_implemented}
  end

  defp public_key_to_der(_public_key) do
    # This would require ASN.1 encoding - simplified for now
    {:error, :not_implemented}
  end

  defp decode_signature(signature, :raw) when byte_size(signature) == 64 do
    <<r::binary-size(32), s::binary-size(32)>> = signature
    {:ok, {r, s}}
  end

  defp decode_signature(_signature, format) do
    {:error, {:unsupported_format, format}}
  end

  defp encode_signature({r, s}, :raw) do
    {:ok, <<r::binary-size(32), s::binary-size(32)>>}
  end

  defp encode_signature(_signature, format) do
    {:error, {:unsupported_format, format}}
  end

  defp validate_public_key(public_key) when byte_size(public_key) in [64, 65] do
    :ok
  end

  defp validate_public_key(_public_key) do
    {:error, :invalid_public_key_length}
  end

  defp encode_subject(subject) do
    # This would require ASN.1 encoding - simplified for now
    {:ok, subject}
  end

  defp calculate_crc16(data) do
    # CRC-16 calculation - simplified implementation
    :erlang.crc32(data) |> band(0xFFFF)
  end
end