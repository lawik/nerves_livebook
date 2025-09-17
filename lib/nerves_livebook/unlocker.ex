defmodule NervesLivebook.Unlocker do
  @moduledoc """
  Mounts encrypted data storage.

  To stop Nerves.Runtime.Init from wiping the encrypted region you must remove the following keys from fwup.conf:

  nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3"
  nerves_fw_application_part0_fstype" => "f2fs"
  nerves_fw_application_part0_target" => "/root"
  """
  use GenServer

  alias Nerves.Runtime
  alias Nerves.Runtime.MountInfo

  require Logger

  @interval 30_000
  @fstype "f2fs"
  @target "/root"
  @devpath "/dev/mmcblk0p3"
  @mapped_name "data"
  @mappedpath "/dev/mapper/data"

  # Use a fixed UUID for the application partition. This has two
  # purposes:
  #
  #   1. mkfs.ext4 calls generate_uuid which calls getrandom(). That
  #      call can block indefinitely until the urandom pool has been
  #      initialized. This will delay startup for a long time if the
  #      app partition needs to be reformated. (mkfs.ext4 has two calls
  #      to getrandom() so this only fixes one of them.)
  #   2. Applications that would prefer to look up a partition by UUID
  #      can do so.
  @app_partition_uuid "3041e38d-615b-48d4-affb-a7787b5c4c39"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def unlock(activation_key) do
    GenServer.call(__MODULE__, {:unlock, activation_key})
  end

  def init(_opts) do
    schedule_auth_check(0)
    {:ok, i2c} = ATECC508A.Transport.I2C.init([])

    {:ok,
     %{
       i2c: i2c,
       mapped: nil,
       mounted: nil,
       fstype: @fstype,
       target: @target,
       devpath: @mappedpath,
       format_performed: false
     }}
  end

  def handle_call({:unlock, activation_key}, _from, state) do
    case do_unlock(state, activation_key) do
      {:ok, state} ->
        {:reply, result, state}

      result ->
        {:reply, result, state}
    end
  end

  defp do_unlock(state, activation_key) do
    padding = 32 - byte_size(activation_key)
    <<_::32-bytes>> = padded_key = <<activation_key::binary, 0::size(padding * 8)>>

    result =
      case ATECC508A.Request.auth_volatile_key(state.i2c, 1, padded_key) do
        :ok ->
          state = set_up_encrypted_filesystem(state)
          {:ok, state}

        _ ->
          {:error, :failed}
      end
  end

  def handle_info(:check_auth, state) do
    state =
      case ATECC508A.Request.get_latch(state.i2c) do
        {:ok, <<1::8, 0::24>>} ->
          Logger.info("Security chip authorized with activation key.")
          set_up_encrypted_filesystem(state)

        _ ->
          Logger.info("Security chip is not authorized. Please provide authorization...")

          state =
            case attempt_auth_sources(state) do
              {:ok, state} ->
                Logger.info("Auth source succeeded.")
                set_up_encrypted_filesystem(state)

              {:error, {:failed, state}} ->
                Logger.info("No auth source succeeded.")
                schedule_auth_check(@interval)
                state
            end

          state
      end

    {:noreply, state}
  end

  defp schedule_auth_check(delay) do
    Process.send_after(self(), :check_auth, delay)
  end

  defp set_up_encrypted_filesystem(state) do
    Logger.info("Setting up encrypted filesystem...")
    data_disk_key = derive_key!(state, "data-disk")
    keyfile_path = "/tmp/keyfile.txt"
    File.write!(keyfile_path, data_disk_key)
    # Mount device mapper
    # cryptsetup open --type=plain --cipher=aes-cbc-plain --key-size=256 --key-file=/tmp/keyfile.txt --verbose -q /dev/mmcblk0p3 data
    case System.cmd(
           "cryptsetup",
           [
             "open",
             "--type=plain",
             "--cipher=aes-cbc-plain",
             "--key-size=256",
             "--key-file=#{keyfile_path}",
             "--verbose",
             "-q",
             @devpath,
             @mapped_name
           ]
         ) do
      {_, 0} ->
        Logger.info("Encrypted filesystem mapped successfully.")
        # Attempt to mount filesystem, stolen from NervesRuntime.Init
        %{state | mapped: true}
        |> mounted_state()
        |> unmount_if_error()
        |> mount()
        |> unmount_if_error()
        |> format_if_unmounted()
        |> mount()
        |> validate_mount()

      # Device mapper already exists
      {_, 5} ->
        Logger.info("Encrypted filesystem mapper already up.")
        # Attempt to mount filesystem, stolen from NervesRuntime.Init
        %{state | mapped: true}
        |> mounted_state()
        |> unmount_if_error()
        |> mount()
        |> unmount_if_error()
        |> format_if_unmounted()
        |> mount()
        |> validate_mount()

      {_, error} ->
        Logger.error("Failed to mount encrypted filesystem: #{error}")
        %{state | mapped: false}
    end
  end

  defp derive_key!(state, tag) do
    # Derive disk encryption key using a tag and the secret encryption key (slot 2)
    {:ok, <<key::32-bytes>>} = ATECC508A.Request.mac_deterministic(state.i2c, 2, pad_end(tag, 32))
    key
  end

  defp pad_end(input, size) do
    padding = size - byte_size(input)
    <<input::binary, 0::size(padding * 8)>>
  end

  defp mounted_state(s) do
    %{s | mounted: MountInfo.get_mounts!() |> mount_point_state(s.target)}
  end

  @doc false
  @spec mount_point_state(MountInfo.mount_info(), String.t()) ::
          :mounted | :mounted_with_error | :unmounted
  def mount_point_state(mounts, target) do
    info = MountInfo.find_by_mount_point(mounts, target)

    cond do
      info == nil -> :unmounted
      MountInfo.read_only?(info) -> :mounted_with_error
      true -> :mounted
    end
  end

  defp mount(%{mounted: :mounted} = s), do: s

  defp mount(s) do
    check_cmd("mount", ["-t", s.fstype, "-o", "rw", s.devpath, s.target], :info)
    mounted_state(s)
  end

  defp unmount_if_error(%{mounted: :mounted_with_error} = s) do
    check_cmd("umount", [s.target], :info)
    mounted_state(s)
  end

  defp unmount_if_error(s), do: s

  defp format_if_unmounted(%{mounted: :unmounted, fstype: fstype, devpath: devpath} = s) do
    Logger.warning(
      "Formatting application partition. If this hangs, it could be waiting on the urandom pool to be initialized"
    )

    mkfs(fstype, devpath)
    %{s | format_performed: true}
  end

  defp format_if_unmounted(s), do: s

  defp mkfs("f2fs", devpath) do
    check_cmd("mkfs.f2fs", ["-f", "#{devpath}"], :info)
  end

  defp mkfs("ext4", devpath) do
    # Remount read-only on errors. The default is to continue on error which
    # partially fails with corruption errors when it fails. Remounting
    # read-only is the previous behavior and seems slightly easier to deal
    # with.
    check_cmd(
      "mkfs.ext4",
      ["-e", "remount-ro", "-U", @app_partition_uuid, "-F", "#{devpath}"],
      :info
    )
  end

  defp mkfs(fstype, devpath) do
    check_cmd("mkfs.#{fstype}", ["-U", @app_partition_uuid, "-F", "#{devpath}"], :info)
  end

  defp check_cmd(cmd, args, out) do
    case Runtime.cmd(cmd, args, out) do
      {_, 0} ->
        :ok

      _ ->
        Logger.warning("Ignoring non-zero exit status from #{cmd} #{inspect(args)}")
        :ok
    end
  end

  defp validate_mount(s), do: s.mounted

  defp attempt_auth_sources(state) do
    # No implementation
    # USB drive mounts automatically
    # Can run `mtype -i /dev/sda1 key` to get the contents of the file `key`
    {:error, {:failed, state}}
  end
end
