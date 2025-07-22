#!/usr/bin/env elixir

# Basic usage example for NervesLivebook.Cryptoauthlib with I2C bus specification
#
# This example demonstrates how to use the cryptoauth library with different I2C buses
# and perform basic cryptographic operations.

defmodule CryptoauthlibExample do
  @moduledoc """
  Example usage of NervesLivebook.Cryptoauthlib with I2C bus configuration.
  """

  alias NervesLivebook.Cryptoauthlib

  def run do
    IO.puts("=== CryptoAuth Library I2C Example ===\n")

    # Try different I2C buses - typically 0, 1, or 2 depending on your system
    i2c_buses = [0, 1, 2]

    Enum.each(i2c_buses, fn bus ->
      IO.puts("Attempting to initialize device on I2C bus #{bus}...")

      case Cryptoauthlib.init(bus) do
        {:ok, device} ->
          IO.puts("✓ Successfully initialized device on I2C bus #{bus}")
          demonstrate_operations(device, bus)

          # Always clean up
          :ok = Cryptoauthlib.release(device)
          IO.puts("✓ Released device resources\n")

        {:error, reason} ->
          IO.puts("✗ Failed to initialize on I2C bus #{bus}: #{inspect(reason)}\n")
      end
    end)
  end

  defp demonstrate_operations(device, bus) do
    IO.puts("  Demonstrating operations on I2C bus #{bus}:")

    # Get device information
    case Cryptoauthlib.get_info(device) do
      {:ok, info} ->
        IO.puts("  ✓ Device info: #{inspect(info)}")
      {:error, reason} ->
        IO.puts("  ✗ Failed to get device info: #{inspect(reason)}")
    end

    # Generate random data
    case Cryptoauthlib.random(device, 16) do
      {:ok, random_data} ->
        IO.puts("  ✓ Generated 16 random bytes: #{Base.encode16(random_data)}")
      {:error, reason} ->
        IO.puts("  ✗ Failed to generate random data: #{inspect(reason)}")
    end

    # Generate a key pair
    slot = 0
    case Cryptoauthlib.genkey(device, slot) do
      {:ok, public_key} ->
        IO.puts("  ✓ Generated key pair in slot #{slot}")
        IO.puts("    Public key: #{Base.encode16(public_key)}")

        # Demonstrate signing and verification
        demonstrate_signing(device, slot)

      {:error, reason} ->
        IO.puts("  ✗ Failed to generate key pair: #{inspect(reason)}")
    end

    # Try reading from config zone
    case Cryptoauthlib.read(device, :config, 0, 0, 4) do
      {:ok, config_data} ->
        IO.puts("  ✓ Read config data: #{Base.encode16(config_data)}")
      {:error, reason} ->
        IO.puts("  ✗ Failed to read config: #{inspect(reason)}")
    end
  end

  defp demonstrate_signing(device, slot) do
    message = "Hello from I2C CryptoAuth device!"
    digest = :crypto.hash(:sha256, message)

    case Cryptoauthlib.sign(device, slot, digest) do
      {:ok, signature} ->
        IO.puts("  ✓ Signed message: \"#{message}\"")
        IO.puts("    Signature: #{Base.encode16(signature)}")

        # Verify the signature
        case Cryptoauthlib.verify(device, slot, digest, signature) do
          {:ok, true} ->
            IO.puts("  ✓ Signature verification passed")
          {:ok, false} ->
            IO.puts("  ✗ Signature verification failed")
          {:error, reason} ->
            IO.puts("  ✗ Signature verification error: #{inspect(reason)}")
        end

      {:error, reason} ->
        IO.puts("  ✗ Failed to sign message: #{inspect(reason)}")
    end
  end

  def run_with_specific_bus(bus) when is_integer(bus) and bus >= 0 do
    IO.puts("=== Testing specific I2C bus #{bus} ===\n")

    case Cryptoauthlib.init(bus) do
      {:ok, device} ->
        IO.puts("✓ Successfully initialized device on I2C bus #{bus}")

        # Perform comprehensive testing
        test_all_functions(device)

        # Clean up
        :ok = Cryptoauthlib.release(device)
        IO.puts("✓ Test complete, device released")

      {:error, reason} ->
        IO.puts("✗ Failed to initialize on I2C bus #{bus}: #{inspect(reason)}")
        IO.puts("Make sure:")
        IO.puts("  1. CryptoAuth device is connected to I2C bus #{bus}")
        IO.puts("  2. I2C bus #{bus} is enabled in your system")
        IO.puts("  3. Device has correct I2C address (default: 0xC0)")
    end
  end

  def run_with_specific_bus(bus) do
    IO.puts("Error: I2C bus must be a non-negative integer, got: #{inspect(bus)}")
  end

  defp test_all_functions(device) do
    IO.puts("Running comprehensive function tests...")

    # Test random number generation with different lengths
    [1, 8, 16, 32]
    |> Enum.each(fn length ->
      case Cryptoauthlib.random(device, length) do
        {:ok, data} ->
          IO.puts("  ✓ Random #{length} bytes: #{Base.encode16(data)}")
        {:error, reason} ->
          IO.puts("  ✗ Random #{length} bytes failed: #{inspect(reason)}")
      end
    end)

    # Test key operations on different slots
    [0, 1, 2]
    |> Enum.each(fn slot ->
      case Cryptoauthlib.genkey(device, slot) do
        {:ok, pubkey} ->
          IO.puts("  ✓ Generated key in slot #{slot}")

          # Try to get the same public key
          case Cryptoauthlib.get_pubkey(device, slot) do
            {:ok, same_pubkey} when same_pubkey == pubkey ->
              IO.puts("  ✓ Retrieved same public key from slot #{slot}")
            {:ok, different_pubkey} ->
              IO.puts("  ⚠ Retrieved different public key from slot #{slot}")
              IO.puts("    Original:  #{Base.encode16(pubkey)}")
              IO.puts("    Retrieved: #{Base.encode16(different_pubkey)}")
            {:error, reason} ->
              IO.puts("  ✗ Failed to retrieve public key from slot #{slot}: #{inspect(reason)}")
          end

        {:error, reason} ->
          IO.puts("  ✗ Failed to generate key in slot #{slot}: #{inspect(reason)}")
      end
    end)

    # Test zone lock status
    [:config, :data]
    |> Enum.each(fn zone ->
      case Cryptoauthlib.is_locked(device, zone) do
        {:ok, locked} ->
          IO.puts("  ✓ #{zone} zone is #{if locked, do: "locked", else: "unlocked"}")
        {:error, reason} ->
          IO.puts("  ✗ Failed to check #{zone} zone lock status: #{inspect(reason)}")
      end
    end)
  end
end

# Run the example if this file is executed directly
if __name__ == :main do
  # Check if a specific bus was provided as argument
  case System.argv() do
    [bus_str] ->
      case Integer.parse(bus_str) do
        {bus, ""} when bus >= 0 ->
          CryptoauthlibExample.run_with_specific_bus(bus)
        _ ->
          IO.puts("Error: Invalid I2C bus number. Please provide a non-negative integer.")
          IO.puts("Usage: elixir basic_usage.exs [i2c_bus_number]")
          System.halt(1)
      end

    [] ->
      # No arguments, try all common buses
      CryptoauthlibExample.run()

    _ ->
      IO.puts("Usage: elixir basic_usage.exs [i2c_bus_number]")
      IO.puts("Examples:")
      IO.puts("  elixir basic_usage.exs     # Try buses 0, 1, 2")
      IO.puts("  elixir basic_usage.exs 1   # Test only bus 1")
      System.halt(1)
  end
end
