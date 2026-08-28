import Config

# Configure the network using vintage_net
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}},
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :delux, indicators: %{default: %{green: "ACT"}}

# The RPi5 supports WPA3 so this enables quick_configure to create WiFi
# configurations that support both WPA2 and WPA3.
config :vintage_net_wifi, :quick_configure, &VintageNetWiFi.Cookbook.generic/2

# See https://github.com/nerves-networking/vintage_net_wifi/pull/315
config :vintage_net_wifi,
  cookbook_extras: %{
    generic: %{vintage_net_wifi: %{sae_pwe: 2}},
    wpa3_sae: %{vintage_net_wifi: %{sae_pwe: 2}}
  }

# See mix.exs
# config :nx, default_backend: NxEigen.Backend

# Put the IEx console on uart0 (GPIO14/15). On the reComputer R22xx that UART
# is behind the CH343 bridge on the USB-C console port. The kernel already
# logs there (console=serial0 in cmdline). Use "ttyAMA10" instead for the
# CM5/RPi5 dedicated debug connector, or "tty1" for HDMI.
config :nerves, :erlinit, ctty: "ttyAMA0"

# --- bodge_hailo / HailoRT ---------------------------------------------------
# The reComputer R22xx carries a Hailo-8 on M.2. nbpr_hailo8 ships HailoRT and
# the PCIe driver into the rootfs; bodge_hailo's NIF compiles against the SDK
# staged in NBPR's global artifact cache (populated by `mix nbpr.build` /
# `nbpr.fetch` — the firmware alias runs nbpr.fetch first). At runtime
# libhailort sits in /usr/lib, so the NIF needs no loader configuration.
hailo_cache =
  [System.user_home!(), ".local/share/nerves/nbpr", "nbpr_hailo8-*-nerves_system_rpi5-*"]
  |> Path.join()
  |> Path.wildcard()
  |> Enum.filter(&File.dir?/1)
  |> List.last()

if is_nil(hailo_cache) do
  Mix.raise("""
  No nbpr_hailo8 artifact found in the NBPR cache. Build it before building
  firmware (it can't be fetched mid-compile):

      cd ../nbpr && MIX_TARGET=rpi5 mix nbpr.build NBPR.Hailo8
  """)
end

config :bodge_hailo,
  backend: :hailo8,
  hailo8_include_dir: Path.join(hailo_cache, "staging/usr/include"),
  hailo8_lib_dir: Path.join(hailo_cache, "staging/usr/lib")
