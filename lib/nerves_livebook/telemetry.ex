defmodule NervesLivebook.Telemetry do
  @moduledoc """
  Local telemetry collection backed by [Mobius](https://hexdocs.pm/mobius).

  This starts a `telemetry_poller` for OS-level measurements (CPU, memory,
  load) and a `Mobius` instance that records system, BEAM, Phoenix and
  LiveView metrics into an on-device time-series store under
  `#{inspect(__MODULE__)}`'s persistence directory.

  Mobius keeps recent history at second/minute/hour/day resolutions and, for
  the metrics below that opt into a DDSketch histogram, supports percentile
  and SLO-style queries. Everything is local: nothing is shipped off the
  device.

  ## Querying from a Livebook (or IEx)

      # Latest values
      Mobius.Exports.series("system.cpu.temperature.celsius", :last_value, %{})
      Mobius.Exports.series("system.memory.used_bytes", :last_value, %{})

      # Plot a metric over the recent window
      Mobius.Exports.plot("system.cpu.temperature.celsius", :last_value, %{})
      Mobius.Exports.plot("vm.memory.total", :last_value, %{})

      # Percentiles from the histograms
      Mobius.Exports.quantile("phoenix.endpoint.stop.duration", 0.99)
      Mobius.Exports.quantiles("phoenix.live_view.handle_event.stop.duration", [0.5, 0.95, 0.99])
      Mobius.Exports.quantile("system.cpu.utilization.percent", 0.95)

      # SLO-style counts (e.g. requests served under 200 ms in the last hour)
      Mobius.Exports.histogram_count_below("phoenix.endpoint.stop.duration", 200, %{}, last: {1, :hour})

  ## Notes

  * Mobius does not apply `Telemetry.Metrics` unit conversions, so durations
    (reported by Phoenix/LiveView in `:native` units) are converted to
    milliseconds here via a `:measurement` function. Byte values are stored
    as-is (bytes).
  * VM metrics (`[:vm, ...]`) are emitted by `telemetry_poller`'s default
    poller, so they are only declared as metrics here, not re-polled.
  * Histograms cost memory and flash. Ranges below are tightened per metric;
    see the Mobius histogram guide before widening them.
  * `Mobius.info/0` currently raises when any histogram is configured (a bug
    on the pinned `histograms` branch), so use `Mobius.Exports` to inspect
    data rather than that helper.
  * `autosave_interval: 60` writes the full history (RRD, including histogram
    snapshots) to `persistence_dir` every 60 s. Without it, Mobius only saves
    on a graceful shutdown, so an ungraceful reboot or firmware update loses
    the in-memory history.
  """

  use Supervisor

  import Telemetry.Metrics

  @poller_period :timer.seconds(5)

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children = [
      {Mobius, metrics: metrics(), persistence_dir: persistence_dir(), autosave_interval: 60},
      {:telemetry_poller,
       measurements: periodic_measurements(), period: @poller_period, name: __MODULE__.Poller}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  The list of `Telemetry.Metrics` definitions tracked by Mobius.
  """
  def metrics() do
    [
      # ---- System: CPU ----
      last_value("system.cpu.utilization.percent"),
      summary("system.cpu.utilization.percent",
        reporter_options: [
          histogram: [min_indexable_value: 0.1, max_indexable_value: 100.0, relative_accuracy: 0.05]
        ]
      ),
      last_value("system.cpu.temperature.celsius"),
      summary("system.cpu.temperature.celsius",
        reporter_options: [
          histogram: [min_indexable_value: 10.0, max_indexable_value: 120.0, relative_accuracy: 0.02]
        ]
      ),

      # ---- System: load average ----
      last_value("system.load.avg1"),
      last_value("system.load.avg5"),
      last_value("system.load.avg15"),

      # ---- System: memory (whole device, in bytes) ----
      last_value("system.memory.total_bytes"),
      last_value("system.memory.available_bytes"),
      last_value("system.memory.used_bytes"),
      last_value("system.memory.used_percent"),
      summary("system.memory.used_bytes",
        reporter_options: [
          histogram: [
            min_indexable_value: 1_048_576.0,
            max_indexable_value: 8_589_934_592.0,
            relative_accuracy: 0.1
          ]
        ]
      ),

      # ---- BEAM / VM (bytes; emitted by telemetry_poller's default poller) ----
      last_value("vm.memory.total"),
      last_value("vm.memory.processes"),
      last_value("vm.memory.binary"),
      last_value("vm.memory.ets"),
      summary("vm.memory.total",
        reporter_options: [
          histogram: [
            min_indexable_value: 1_048_576.0,
            max_indexable_value: 1_073_741_824.0,
            relative_accuracy: 0.1
          ]
        ]
      ),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      summary("vm.total_run_queue_lengths.total",
        reporter_options: [
          histogram: [min_indexable_value: 0.1, max_indexable_value: 1_000.0, relative_accuracy: 0.1]
        ]
      ),
      last_value("vm.system_counts.process_count"),
      last_value("vm.system_counts.atom_count"),
      last_value("vm.system_counts.port_count"),

      # ---- Phoenix (Livebook's web layer) ----
      counter("phoenix.endpoint.stop.count"),
      summary("phoenix.endpoint.stop.duration",
        measurement: &duration_to_ms/1,
        reporter_options: [histogram: latency_histogram()]
      ),
      summary("phoenix.router_dispatch.stop.duration",
        measurement: &duration_to_ms/1,
        tags: [:route]
      ),
      counter("phoenix.error_rendered.count"),
      counter("phoenix.socket_connected.count"),
      counter("phoenix.channel_joined.count"),

      # ---- Phoenix LiveView (the bulk of Livebook interaction) ----
      counter("phoenix.live_view.mount.stop.count"),
      summary("phoenix.live_view.mount.stop.duration",
        measurement: &duration_to_ms/1,
        reporter_options: [histogram: latency_histogram()]
      ),
      counter("phoenix.live_view.handle_event.stop.count"),
      summary("phoenix.live_view.handle_event.stop.duration",
        measurement: &duration_to_ms/1,
        reporter_options: [histogram: latency_histogram()]
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        measurement: &duration_to_ms/1
      )
    ]
  end

  # Shared histogram tuning for request/interaction latency: 0.1 ms - 60 s,
  # +-10% quantile error. Plenty for "did P99 cross budget?".
  defp latency_histogram() do
    [min_indexable_value: 0.1, max_indexable_value: 60_000.0, relative_accuracy: 0.1]
  end

  # Phoenix/LiveView report :duration in native time units. Convert to
  # floating-point milliseconds so histogram ranges (above) are in ms.
  defp duration_to_ms(%{duration: duration}) do
    System.convert_time_unit(duration, :native, :nanosecond) / 1_000_000
  end

  defp periodic_measurements() do
    [
      {__MODULE__, :dispatch_cpu_utilization, []},
      {__MODULE__, :dispatch_cpu_temperature, []},
      {__MODULE__, :dispatch_load_average, []},
      {__MODULE__, :dispatch_system_memory, []}
    ]
  end

  # The functions below are invoked by telemetry_poller. They must never
  # raise: a raising measurement is permanently dropped by the poller, so each
  # guards itself and returns :ok on any failure.

  @doc false
  def dispatch_cpu_utilization() do
    with {:ok, stat} <- File.read("/proc/stat"),
         {:ok, total, idle} <- parse_proc_stat(stat) do
      previous = Process.put(:cpu_stat, {total, idle})

      case previous do
        {prev_total, prev_idle} when total - prev_total > 0 ->
          delta_total = total - prev_total
          delta_idle = idle - prev_idle
          percent = (delta_total - delta_idle) / delta_total * 100.0
          :telemetry.execute([:system, :cpu, :utilization], %{percent: percent})

        _ ->
          :ok
      end
    end

    :ok
  rescue
    _ -> :ok
  end

  @doc false
  def dispatch_cpu_temperature() do
    with {:ok, content} <- File.read("/sys/class/thermal/thermal_zone0/temp"),
         {millidegrees, _} <- Integer.parse(String.trim(content)) do
      :telemetry.execute([:system, :cpu, :temperature], %{celsius: millidegrees / 1000})
    end

    :ok
  rescue
    _ -> :ok
  end

  @doc false
  def dispatch_load_average() do
    with {:ok, content} <- File.read("/proc/loadavg"),
         [a, b, c | _] <- String.split(content, " ", parts: 4),
         {avg1, _} <- Float.parse(a),
         {avg5, _} <- Float.parse(b),
         {avg15, _} <- Float.parse(c) do
      :telemetry.execute([:system, :load], %{avg1: avg1, avg5: avg5, avg15: avg15})
    end

    :ok
  rescue
    _ -> :ok
  end

  @doc false
  def dispatch_system_memory() do
    with {:ok, content} <- File.read("/proc/meminfo"),
         %{"MemTotal" => total_kb, "MemAvailable" => available_kb} <- parse_meminfo(content) do
      total = total_kb * 1024
      available = available_kb * 1024
      used = total - available

      :telemetry.execute([:system, :memory], %{
        total_bytes: total,
        available_bytes: available,
        used_bytes: used,
        used_percent: if(total > 0, do: used / total * 100, else: 0.0)
      })
    end

    :ok
  rescue
    _ -> :ok
  end

  # /proc/stat first line: "cpu  user nice system idle iowait irq softirq ..."
  # Idle time counts both idle and iowait.
  defp parse_proc_stat(stat) do
    [first | _] = String.split(stat, "\n", parts: 2)
    ["cpu" | fields] = String.split(first, " ", trim: true)
    nums = Enum.map(fields, &String.to_integer/1)
    total = Enum.sum(nums)
    idle = Enum.at(nums, 3, 0) + Enum.at(nums, 4, 0)
    {:ok, total, idle}
  rescue
    _ -> :error
  end

  # /proc/meminfo lines like "MemTotal:  8167848 kB" -> %{"MemTotal" => 8167848}
  defp parse_meminfo(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, &put_meminfo_entry/2)
  end

  defp put_meminfo_entry(line, acc) do
    with [key, rest] <- String.split(line, ":", parts: 2),
         {kb, _} <- Integer.parse(String.trim(rest)) do
      Map.put(acc, key, kb)
    else
      _ -> acc
    end
  end

  defp persistence_dir() do
    if Nerves.Runtime.mix_target() == :host do
      Path.join(System.tmp_dir!(), "nerves_livebook_mobius")
    else
      "/data"
    end
  end
end
