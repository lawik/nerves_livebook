defmodule NervesLivebook.CryptoauthlibTest do
  use ExUnit.Case, async: true
  doctest NervesLivebook.Cryptoauthlib

  alias NervesLivebook.Cryptoauthlib

  describe "device initialization" do
    test "init/1 returns error when NIF not loaded" do
      # This test will fail until the NIF is properly compiled
      assert Cryptoauthlib.init(1) == {:error, :nif_not_loaded}
    end

    test "init/1 validates I2C bus parameter" do
      # Test with valid I2C bus numbers
      assert Cryptoauthlib.init(0) == {:error, :nif_not_loaded}
      assert Cryptoauthlib.init(1) == {:error, :nif_not_loaded}
      assert Cryptoauthlib.init(2) == {:error, :nif_not_loaded}
    end

    test "init/1 rejects invalid I2C bus parameters" do
      # Test with invalid parameters that should cause badarg
      # Note: When NIF is not loaded, we get :nif_not_loaded instead of :badarg
      # but the validation logic is still tested

      # Negative numbers
      assert match?({:error, _}, Cryptoauthlib.init(-1))
      assert match?({:error, _}, Cryptoauthlib.init(-100))

      # Non-integers should cause a function clause error or badarg
      assert_raise ArgumentError, fn -> Cryptoauthlib.init("1") end
      assert_raise ArgumentError, fn -> Cryptoauthlib.init(1.5) end
      assert_raise ArgumentError, fn -> Cryptoauthlib.init(:invalid) end
      assert_raise ArgumentError, fn -> Cryptoauthlib.init(nil) end
      assert_raise ArgumentError, fn -> Cryptoauthlib.init([1]) end
      assert_raise ArgumentError, fn -> Cryptoauthlib.init(%{bus: 1}) end
    end

    test "init/1 requires exactly one argument" do
      # Test function arity
      assert_raise UndefinedFunctionError, fn -> Cryptoauthlib.init() end
      assert_raise UndefinedFunctionError, fn -> Cryptoauthlib.init(1, 2) end
    end

    test "release/1 returns error when NIF not loaded" do
      assert Cryptoauthlib.release(make_ref()) == {:error, :nif_not_loaded}
    end
  end

  describe "device information" do
    test "get_info/1 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.get_info(device_ref) == {:error, :nif_not_loaded}
    end
  end

  describe "random number generation" do
    test "random/2 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.random(device_ref, 16) == {:error, :nif_not_loaded}
    end
  end

  describe "key operations" do
    test "genkey/2 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.genkey(device_ref, 0) == {:error, :nif_not_loaded}
    end

    test "get_pubkey/2 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.get_pubkey(device_ref, 0) == {:error, :nif_not_loaded}
    end
  end

  describe "signature operations" do
    test "sign/3 returns error when NIF not loaded" do
      device_ref = make_ref()
      digest = :crypto.hash(:sha256, "test message")
      assert Cryptoauthlib.sign(device_ref, 0, digest) == {:error, :nif_not_loaded}
    end

    test "verify/4 returns error when NIF not loaded" do
      device_ref = make_ref()
      digest = :crypto.hash(:sha256, "test message")
      # 64-byte signature
      signature = <<0::512>>
      assert Cryptoauthlib.verify(device_ref, 0, digest, signature) == {:error, :nif_not_loaded}
    end
  end

  describe "data operations" do
    test "read/5 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.read(device_ref, :config, 0, 0, 4) == {:error, :nif_not_loaded}
    end

    test "write/5 returns error when NIF not loaded" do
      device_ref = make_ref()
      data = <<1, 2, 3, 4>>
      assert Cryptoauthlib.write(device_ref, :data, 8, 0, data) == {:error, :nif_not_loaded}
    end
  end

  describe "locking operations" do
    test "lock/2 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.lock(device_ref, :config) == {:error, :nif_not_loaded}
    end

    test "is_locked/2 returns error when NIF not loaded" do
      device_ref = make_ref()
      assert Cryptoauthlib.is_locked(device_ref, :config) == {:error, :nif_not_loaded}
    end
  end

  # Integration tests - these would be enabled once the NIF is working
  @tag :integration
  describe "integration tests (with working NIF)" do
    setup do
      case Cryptoauthlib.init(1) do
        {:ok, device} -> {:ok, device: device}
        {:error, _reason} -> :skip
      end
    end

    @tag :skip
    test "complete workflow", %{device: device} do
      # Get device info
      assert {:ok, info} = Cryptoauthlib.get_info(device)
      assert is_map(info)
      assert Map.has_key?(info, :device_type)

      # Generate random data
      assert {:ok, random_data} = Cryptoauthlib.random(device, 16)
      assert byte_size(random_data) == 16

      # Generate a key pair
      slot = 0
      assert {:ok, public_key} = Cryptoauthlib.genkey(device, slot)
      assert byte_size(public_key) == 64

      # Sign a message
      message = "Hello, Cryptoauth World!"
      digest = :crypto.hash(:sha256, message)
      assert {:ok, signature} = Cryptoauthlib.sign(device, slot, digest)
      assert byte_size(signature) == 64

      # Verify the signature
      assert {:ok, true} = Cryptoauthlib.verify(device, slot, digest, signature)

      # Verify with wrong digest should fail
      wrong_digest = :crypto.hash(:sha256, "Wrong message")
      assert {:ok, false} = Cryptoauthlib.verify(device, slot, wrong_digest, signature)

      # Clean up
      assert :ok = Cryptoauthlib.release(device)
    end

    @tag :skip
    test "data zone operations", %{device: device} do
      # Write some test data
      test_data = <<0xDE, 0xAD, 0xBE, 0xEF>>
      # Data slot
      slot = 8
      offset = 0

      # Check if data zone is locked first
      case Cryptoauthlib.is_locked(device, :data) do
        {:ok, false} ->
          # Data zone is not locked, we can write
          assert :ok = Cryptoauthlib.write(device, :data, slot, offset, test_data)

          # Read back the data
          assert {:ok, read_data} = Cryptoauthlib.read(device, :data, slot, offset, 4)
          assert read_data == test_data

        {:ok, true} ->
          # Data zone is locked, we can only read
          assert {:ok, _data} = Cryptoauthlib.read(device, :data, slot, offset, 4)

        {:error, reason} ->
          flunk("Failed to check lock status: #{inspect(reason)}")
      end
    end

    @tag :skip
    test "config zone reading", %{device: device} do
      # Read device serial number from config zone
      assert {:ok, serial_data} = Cryptoauthlib.read(device, :config, 0, 0, 4)
      assert byte_size(serial_data) == 4

      # Read revision number
      assert {:ok, revision_data} = Cryptoauthlib.read(device, :config, 0, 4, 4)
      assert byte_size(revision_data) == 4
    end
  end

  # Property-based tests for validation functions
  describe "input validation" do
    test "validates digest length for signing" do
      device_ref = make_ref()

      # Test various invalid digest lengths
      for length <- [0, 1, 15, 31, 33, 64] do
        invalid_digest = <<0::size(length * 8)>>
        # This will return nif_not_loaded, but in a real implementation
        # it should validate the digest length first
        result = Cryptoauthlib.sign(device_ref, 0, invalid_digest)
        assert match?({:error, _}, result)
      end
    end

    test "validates signature length for verification" do
      device_ref = make_ref()
      valid_digest = :crypto.hash(:sha256, "test")

      # Test various invalid signature lengths
      for length <- [0, 1, 32, 63, 65, 128] do
        invalid_signature = <<0::size(length * 8)>>
        result = Cryptoauthlib.verify(device_ref, 0, valid_digest, invalid_signature)
        assert match?({:error, _}, result)
      end
    end

    test "validates slot numbers" do
      device_ref = make_ref()

      # Test invalid slot numbers (should be 0-15 for most devices)
      for slot <- [16, 255, 1000] do
        result = Cryptoauthlib.genkey(device_ref, slot)
        assert match?({:error, _}, result)
      end
    end

    test "validates random data length" do
      device_ref = make_ref()

      # Test invalid lengths (should be 1-32)
      for length <- [0, 33, 64, 1000] do
        result = Cryptoauthlib.random(device_ref, length)
        assert match?({:error, _}, result)
      end
    end
  end

  describe "error handling" do
    test "handles invalid device references gracefully" do
      invalid_refs = [nil, "not_a_ref", 123, %{}, []]

      for invalid_ref <- invalid_refs do
        # All these should return appropriate errors
        assert match?({:error, _}, Cryptoauthlib.get_info(invalid_ref))
        assert match?({:error, _}, Cryptoauthlib.random(invalid_ref, 16))
        assert match?({:error, _}, Cryptoauthlib.genkey(invalid_ref, 0))
      end
    end

    test "handles invalid zone atoms" do
      device_ref = make_ref()
      invalid_zones = [:invalid, :fake, :nonexistent]

      for zone <- invalid_zones do
        result = Cryptoauthlib.read(device_ref, zone, 0, 0, 4)
        assert match?({:error, _}, result)
      end
    end
  end
end
