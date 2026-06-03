defmodule NervesLivebook.MobiusUI do
  @moduledoc """
  Nicer text-mode graphs and plots for Mobius metrics, built on `term_ui`.

  Mobius ships its own ASCII chart via `Mobius.Exports.plot/4`. It works, but it is
  coarse: a single series of `*` characters with no color. The widgets in
  [`term_ui`](https://hexdocs.pm/term_ui) render with Unicode braille and block
  glyphs at sub-character resolution, in color, so the same data reads far better in
  a Livebook output or an IEx session on the device.

  This module is a thin, render-only adapter. It is built to take the query-ready
  structures from `Mobius.Charts` straight through to the matching `term_ui` widget —
  `Mobius.Charts` does the data wrangling (sorted bins, a line per quantile, latest
  values), this module only draws. Each function also accepts the plainer shapes
  (lists of numbers/points, `{value, count}` bins) for quick ad-hoc use, then flattens
  the resulting render tree into an ANSI string.

  Each builder returns a `Kino.Text` (with `terminal: true`) by default so it renders
  inline in Livebook. Pass `as: :string` to get the raw ANSI string instead — handy
  for `IO.puts/1` over the device console.

  ## Examples

  A metric over time — pass a `Mobius.Charts.series/4` result straight in; the title
  defaults to the metric name:

      "system.cpu.temperature.celsius"
      |> Mobius.Charts.series(:last_value, %{}, last: {5, :minute})
      |> NervesLivebook.MobiusUI.line()

  Quantiles over time — one colored line per quantile, with a legend, from a single
  `Mobius.Charts.quantiles_over_time/4` result:

      {:ok, qot} = Mobius.Charts.quantiles_over_time("phoenix.endpoint.stop.duration", [0.5, 0.95, 0.99], %{}, last: {1, :hour})
      NervesLivebook.MobiusUI.line(qot)

  A distribution as a bar chart, and latest values as bars:

      {:ok, dist} = Mobius.Charts.distribution("phoenix.endpoint.stop.duration", %{}, last: {1, :hour})
      NervesLivebook.MobiusUI.histogram(dist)

      [{"vm.memory.total", :last_value}, {"vm.memory.processes", :last_value}]
      |> Mobius.Charts.latest(last: {5, :minute})
      |> NervesLivebook.MobiusUI.bars(title: "BEAM memory")

  A one-line trend, and a single gauge:

      NervesLivebook.MobiusUI.sparkline([1, 3, 5, 2, 8, 4])
      NervesLivebook.MobiusUI.gauge(72.5, min: 0, max: 100, label: "CPU temp")
  """

  alias TermUI.Component.RenderNode
  alias TermUI.Renderer.Style
  alias TermUI.Widgets.{BarChart, Gauge, LineChart, Sparkline}

  # Colors cycled through for multi-series line charts and bar groups.
  @palette [:cyan, :magenta, :yellow, :green, :blue, :red, :bright_cyan, :bright_magenta]

  @doc """
  Render a line chart using braille glyphs for sub-character resolution.

  `data` may be:

    * a `Mobius.Charts.series/4` result (`%{points: [...], metric: ...}`) — a single
      line, titled with the metric name unless `:title` overrides it
    * a `Mobius.Charts.quantiles_over_time/4` result (`%{lines: [...]}`) — one colored
      line per quantile, with a legend (`p50`, `p95`, …)
    * a flat list of numbers — a single line
    * a list of points: `{timestamp, value}` tuples or `%{value: v}` / `%{y: v}` maps
    * a list of `{label, values}` pairs — one colored line per label, with a legend

  ## Options

    * `:title` - heading printed above the chart (defaults to the metric name when
      given a `Mobius.Charts` result)
    * `:width` - chart width in characters (default: 60)
    * `:height` - chart height in characters (default: 12)
    * `:show_axis` - draw axis lines (default: true)
    * `:as` - `:kino` (default) or `:string`
  """
  @spec line(term(), keyword()) :: term()
  def line(data, opts \\ []) do
    {pairs, default_title} = normalize_line(data)
    labeled? = match?([{label, _} | _] when is_binary(label), pairs)

    chart_series =
      pairs
      |> Enum.with_index()
      |> Enum.map(fn {{_label, values}, index} ->
        %{data: values, color: Enum.at(@palette, rem(index, length(@palette)))}
      end)

    node =
      LineChart.render(
        series: chart_series,
        width: Keyword.get(opts, :width, 60),
        height: Keyword.get(opts, :height, 12),
        show_axis: Keyword.get(opts, :show_axis, true)
      )

    legend = if labeled?, do: legend_line(chart_series, pairs)
    output([title_line(opts, default_title), node_to_string(node), legend], opts)
  end

  @doc """
  Render a compact single-line sparkline (`▁▂▃▄▅▆▇█`) of a value series.

  Accepts a `Mobius.Charts.series/4` result or any of the single-line shapes `line/2`
  takes. Great for an inline trend next to a label. Options: `:title`, `:as`.
  """
  @spec sparkline(term(), keyword()) :: term()
  def sparkline(data, opts \\ []) do
    {[{_label, values} | _], default_title} = normalize_line(data)
    node = Sparkline.render(values: values)
    output([title_line(opts, default_title), node_to_string(node)], opts)
  end

  @doc """
  Render a horizontal bar chart from labeled values.

  `data` may be a `Mobius.Charts.latest/2` result (a list of `%{metric:, value:}`
  maps), a list of `{label, value}` tuples, or `%{label:, value:}` /
  `%{"metric" => ..., "value" => ...}` maps.

  ## Options

    * `:title` - heading printed above the chart
    * `:width` - chart width in characters (default: 50)
    * `:show_values` - print the numeric value after each bar (default: true)
    * `:as` - `:kino` (default) or `:string`
  """
  @spec bars(term(), keyword()) :: term()
  def bars(data, opts \\ []) do
    node =
      BarChart.render(
        data: to_bar_data(data),
        direction: :horizontal,
        width: Keyword.get(opts, :width, 50),
        show_values: Keyword.get(opts, :show_values, true),
        colors: Enum.map(@palette, &Style.new(fg: &1))
      )

    output([title_line(opts, nil), node_to_string(node)], opts)
  end

  @doc """
  Render a distribution (histogram) as a horizontal bar chart.

  `data` may be a `Mobius.Charts.distribution/3` result (`%{bins: [%{value:, count:}],
  metric: ...}`) — titled with the metric name unless `:title` overrides — or a plain
  list of `{value, count}` / `%{value:, count:}` bins. The bin's representative value
  becomes the bar label and its count the bar length. Takes the same options as
  `bars/2`.
  """
  @spec histogram(term(), keyword()) :: term()
  def histogram(data, opts \\ []) do
    {bins, default_title} = normalize_bins(data)
    rows = Enum.map(bins, fn {value, count} -> {format_number(value), count} end)
    bars(rows, opts |> Keyword.put_new(:width, 40) |> Keyword.put_new(:title, default_title))
  end

  @doc """
  Render a single value as a gauge bar within a range.

  ## Options

    * `:min` / `:max` - range bounds (defaults: 0 / 100)
    * `:label` - text label for the gauge
    * `:width` - gauge width in characters (default: 40)
    * `:zones` - list of `{threshold, color}` for colored zones,
      e.g. `[{0, :green}, {60, :yellow}, {85, :red}]`
    * `:as` - `:kino` (default) or `:string`
  """
  @spec gauge(number(), keyword()) :: term()
  def gauge(value, opts \\ []) do
    node =
      Gauge.render(
        value: value,
        min: Keyword.get(opts, :min, 0),
        max: Keyword.get(opts, :max, 100),
        width: Keyword.get(opts, :width, 40),
        label: Keyword.get(opts, :label),
        zones: to_zones(Keyword.get(opts, :zones, []))
      )

    output([node_to_string(node)], opts)
  end

  # Accept `{threshold, :color}` for convenience, or a ready `%Style{}`.
  defp to_zones(zones) do
    Enum.map(zones, fn
      {threshold, %Style{} = style} -> {threshold, style}
      {threshold, color} when is_atom(color) -> {threshold, Style.new(fg: color)}
    end)
  end

  @doc """
  Print a sampler of charts for `metric` over the last 24 hours, straight to the
  console. Built for IEx — it prints with `IO.puts/1` and returns `:ok`.

  A braille line chart each for the average and the p50/p90/p99 quantiles, then the
  full distribution as a bar chart. Defaults to CPU utilization, a histogram-enabled
  metric that always has data.

      iex> NervesLivebook.MobiusUI.demo()
      iex> NervesLivebook.MobiusUI.demo("phoenix.endpoint.stop.duration")

  Pass `mobius_instance:` if your instance is not the auto-detected one.

  `demo(:kitty)` renders the same metric as a true raster image using the kitty
  graphics protocol instead of braille glyphs. It only shows up on a terminal
  that speaks the protocol (kitty, ghostty, WezTerm, Konsole); elsewhere the
  escape sequence is ignored. Pass `metric:` to chart something other than CPU.
  """
  @spec demo(Mobius.metric_name() | :kitty, keyword()) :: :ok
  def demo(metric_or_mode \\ "system.cpu.utilization.percent", opts \\ [])

  def demo(:kitty, opts), do: kitty_demo(opts)

  def demo(metric, opts) do
    instance = Keyword.get(opts, :mobius_instance, find_instance())
    window = [last: {24, :hour}, mobius_instance: instance]

    IO.puts("\n" <> ansi(metric <> " — last 24h", :bright_cyan, [:bold]))

    metric
    |> Mobius.Charts.series({:summary, :average}, %{}, window)
    |> Map.fetch!(:points)
    |> print_line("average")

    case Mobius.Charts.quantiles_over_time(metric, [0.5, 0.9, 0.99], %{}, window) do
      {:ok, qot} ->
        qot.lines
        |> Enum.zip(["p50", "p90", "p99"])
        |> Enum.each(fn {%{points: points}, label} -> print_line(points, label) end)

      {:error, _} ->
        IO.puts(ansi("  (metric has no histogram enabled)", :bright_black))
    end

    IO.puts("")

    case Mobius.Charts.distribution(metric, %{}, window) do
      {:ok, %{total_count: 0}} ->
        IO.puts(
          ansi("distribution", :bright_white, [:bold]) <>
            "  " <> ansi("(no observations)", :bright_black)
        )

      {:ok, dist} ->
        IO.puts(histogram(dist, as: :string, title: "distribution"))

      {:error, _} ->
        IO.puts(
          ansi("distribution", :bright_white, [:bold]) <>
            "  " <> ansi("(metric has no histogram enabled)", :bright_black)
        )
    end

    IO.puts("")
    :ok
  end

  # --- kitty graphics demo -------------------------------------------------

  # Pixel size of the rasterized chart and its palette (background, line).
  @kitty_width 480
  @kitty_height 160
  @kitty_bg {16, 18, 24}
  @kitty_fg {0, 220, 200}

  # The :kitty variant of demo/2. Draws one Mobius series as actual pixels and
  # writes the kitty graphics escape sequence to the console. The data path is
  # the same as the braille demo — only the rendering differs.
  defp kitty_demo(opts) do
    metric = Keyword.get(opts, :metric, "system.cpu.utilization.percent")
    instance = Keyword.get(opts, :mobius_instance, find_instance())
    window = [last: {24, :hour}, mobius_instance: instance]

    values =
      metric
      |> Mobius.Charts.series({:summary, :average}, %{}, window)
      |> Map.fetch!(:points)
      |> Enum.map(& &1.value)

    IO.puts("\n" <> ansi(metric <> " — last 24h", :bright_cyan, [:bold]))

    case values do
      [] ->
        IO.puts(ansi("  (no data)", :bright_black))

      _ ->
        rgb = rasterize_line(values, @kitty_width, @kitty_height, @kitty_fg, @kitty_bg)
        IO.write(kitty_image(rgb, @kitty_width, @kitty_height))
        IO.puts("")
    end

    :ok
  end

  # Draw a connected line chart into a W*H 24-bit RGB pixel buffer (row-major,
  # 3 bytes per pixel). Values are sampled across the columns and the gap
  # between adjacent columns is filled vertically so the line stays continuous.
  defp rasterize_line(values, w, h, fg, bg) do
    {vmin, vmax} = Enum.min_max(values)
    n = length(values)
    cols = List.to_tuple(values)

    # Pixel row (0 = top) for the value plotted at column `x`.
    col_y = fn x ->
      idx = if n == 1, do: 0, else: round(x * (n - 1) / (w - 1))
      v = elem(cols, idx)
      frac = if vmax == vmin, do: 0.5, else: (v - vmin) / (vmax - vmin)
      h - 1 - round(frac * (h - 1))
    end

    lit =
      Enum.reduce(1..(w - 1)//1, %{{0, col_y.(0)} => fg}, fn x, acc ->
        y0 = col_y.(x - 1)
        y1 = col_y.(x)
        Enum.reduce(min(y0, y1)..max(y0, y1)//1, acc, &Map.put(&2, {x, &1}, fg))
      end)

    for y <- 0..(h - 1)//1, x <- 0..(w - 1)//1, into: <<>> do
      {r, g, b} = Map.get(lit, {x, y}, bg)
      <<r, g, b>>
    end
  end

  # Wrap a raw RGB buffer in the kitty graphics protocol: transmit-and-display
  # (a=T) a 24-bit image (f=24) of the given pixel size, base64-encoded directly
  # in the escape (t=d). The payload is split into <=4096-byte chunks, each but
  # the last flagged m=1, as the protocol requires.
  defp kitty_image(rgb, w, h) do
    case rgb |> Base.encode64() |> chunk_string(4096) do
      [only] ->
        "\e_Ga=T,f=24,s=#{w},v=#{h};#{only}\e\\"

      [first | rest] ->
        {mids, [last]} = Enum.split(rest, -1)

        [
          "\e_Ga=T,f=24,s=#{w},v=#{h},m=1;#{first}\e\\",
          Enum.map(mids, &"\e_Gm=1;#{&1}\e\\"),
          "\e_Gm=0;#{last}\e\\"
        ]
        |> IO.iodata_to_binary()
    end
  end

  defp chunk_string(str, size) do
    case str do
      <<chunk::binary-size(size), rest::binary>> when rest != <<>> ->
        [chunk | chunk_string(rest, size)]

      _ ->
        [str]
    end
  end

  @demo_chart_width 60
  @demo_chart_height 8

  # A labeled braille line chart for one series, framed with axis labels: the
  # value min/max down the left edge and the time span along the bottom.
  defp print_line(points, label) do
    values = Enum.map(points, & &1.value)
    heading = ansi(label, :bright_white, [:bold])

    case values do
      [] ->
        IO.puts("\n" <> heading <> "  " <> ansi("(no data)", :bright_black))

      _ ->
        last = ansi("(last #{format_number(List.last(values))})", :bright_black)
        IO.puts("\n" <> heading <> "  " <> last)
        IO.puts(framed_line(points, values))
    end
  end

  # Wrap the bare braille chart in a y-axis gutter (max at top, min at bottom)
  # and an x-axis line labeled with the window's start and "now".
  defp framed_line(points, values) do
    rows =
      values
      |> line(width: @demo_chart_width, height: @demo_chart_height, show_axis: false, as: :string)
      |> String.split("\n")

    {min, max} = Enum.min_max(values)
    max_label = format_number(max)
    min_label = format_number(min)
    gutter = max(String.length(max_label), String.length(min_label))
    last_row = length(rows) - 1

    body =
      rows
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {row, i} ->
        label =
          cond do
            i == 0 -> String.pad_leading(max_label, gutter)
            i == last_row -> String.pad_leading(min_label, gutter)
            true -> String.duplicate(" ", gutter)
          end

        ansi(label, :bright_black) <> " │ " <> row
      end)

    axis = String.duplicate(" ", gutter) <> " └" <> String.duplicate("─", @demo_chart_width)

    body <>
      "\n" <>
      ansi(axis, :bright_black) <> "\n" <> ansi(x_axis_label(points, gutter), :bright_black)
  end

  # "  24h ago                                                          now"
  defp x_axis_label(points, gutter) do
    span = List.last(points).timestamp - hd(points).timestamp
    left = "#{format_duration(span)} ago"
    right = "now"
    pad = max(@demo_chart_width - String.length(left) - String.length(right), 1)
    String.duplicate(" ", gutter + 3) <> left <> String.duplicate(" ", pad) <> right
  end

  defp format_duration(seconds) when seconds >= 3600, do: "#{div(seconds, 3600)}h"
  defp format_duration(seconds) when seconds >= 60, do: "#{div(seconds, 60)}m"
  defp format_duration(seconds), do: "#{seconds}s"

  # Find the running Mobius instance the way the sample notebooks do, defaulting
  # to the conventional `:mobius` name.
  defp find_instance do
    Enum.find_value(Process.registered(), :mobius, fn name ->
      case Atom.to_string(name) do
        "Elixir.Mobius.Scraper." <> instance -> String.to_atom(instance)
        _ -> nil
      end
    end)
  end

  # --- line input normalization --------------------------------------------

  # Normalize any accepted line input into `{[{label | nil, [number]}], default_title}`.

  # Mobius.Charts.quantiles_over_time/4 result: one labeled line per quantile.
  defp normalize_line(%{lines: lines, metric: metric}) do
    pairs =
      Enum.map(lines, fn %{quantile: q, points: points} ->
        {quantile_label(q), point_values(points)}
      end)

    {pairs, to_string(metric)}
  end

  # Mobius.Charts.series/4 result: a single line titled with the metric.
  defp normalize_line(%{points: points, metric: metric}) do
    {[{nil, point_values(points)}], to_string(metric)}
  end

  # A list of `{label, values}` pairs -> one labeled line each.
  defp normalize_line([{label, values} | _] = pairs) when is_binary(label) and is_list(values) do
    {Enum.map(pairs, fn {label, values} -> {label, to_numbers(values)} end), nil}
  end

  # A flat list of numbers or points -> a single unlabeled line.
  defp normalize_line(values) when is_list(values) do
    {[{nil, to_numbers(values)}], nil}
  end

  defp point_values(points), do: Enum.map(points, & &1.value)

  # Pull numeric y-values out of the looser ad-hoc shapes.
  defp to_numbers(values) when is_list(values), do: Enum.map(values, &to_number/1)

  defp to_number(n) when is_number(n), do: n
  defp to_number({_x, y}) when is_number(y), do: y
  defp to_number(%{value: v}) when is_number(v), do: v
  defp to_number(%{"value" => v}) when is_number(v), do: v
  defp to_number(%{y: v}) when is_number(v), do: v

  # "p50", "p95", "p99.9" — drop a trailing ".0" so whole percents stay clean.
  defp quantile_label(q) do
    pct = q * 100
    digits = if pct == Float.round(pct), do: trunc(pct), else: Float.round(pct, 3)
    "p#{digits}"
  end

  # --- bar / histogram input normalization ---------------------------------

  defp to_bar_data(data) when is_list(data), do: Enum.map(data, &to_bar_point/1)

  defp to_bar_point({label, value}), do: %{label: to_string(label), value: value}
  defp to_bar_point(%{metric: l, value: v}), do: %{label: to_string(l), value: v}
  defp to_bar_point(%{label: l, value: v}), do: %{label: to_string(l), value: v}
  defp to_bar_point(%{"metric" => l, "value" => v}), do: %{label: to_string(l), value: v}
  defp to_bar_point(%{"label" => l, "value" => v}), do: %{label: to_string(l), value: v}

  # Normalize histogram input into `{[{value, count}], default_title}`.
  defp normalize_bins(%{bins: bins, metric: metric}) do
    {Enum.map(bins, fn %{value: v, count: c} -> {v, c} end), to_string(metric)}
  end

  defp normalize_bins(bins) when is_list(bins) do
    {Enum.map(bins, &normalize_bin/1), nil}
  end

  defp normalize_bin({value, count}), do: {value, count}
  defp normalize_bin(%{value: v, count: c}), do: {v, c}

  # --- legend / titles -----------------------------------------------------

  defp legend_line(chart_series, pairs) do
    chart_series
    |> Enum.zip(Enum.map(pairs, fn {name, _values} -> name end))
    |> Enum.map_join("   ", fn {%{color: color}, name} -> ansi("●", color) <> " " <> name end)
  end

  # The explicit `:title` always wins; otherwise fall back to a metric-derived one.
  defp title_line(opts, default_title) do
    case Keyword.get(opts, :title, default_title) do
      nil -> nil
      title -> ansi(title, :bright_white, [:bold])
    end
  end

  # --- render tree -> ANSI string -----------------------------------------

  defp node_to_string(node) do
    node
    |> node_to_block(nil)
    |> Enum.map_join("\n", &line_to_string/1)
  end

  # A block is a list of lines; a line is a list of {text, style} segments.
  # `inherited` carries a style down from an enclosing styled box (term_ui's
  # `styled/2` wraps a node in a :box whose style applies to its children).
  defp node_to_block(%RenderNode{type: :empty}, _inherited), do: []

  defp node_to_block(%RenderNode{type: :text, content: content, style: style}, inherited) do
    [[{content, style || inherited}]]
  end

  defp node_to_block(
         %RenderNode{type: :stack, direction: :horizontal, children: children},
         inherited
       ) do
    children
    |> Enum.map(&node_to_block(&1, inherited))
    |> Enum.reject(&(&1 == []))
    |> zip_horizontal()
  end

  defp node_to_block(%RenderNode{type: :box, style: style, children: children}, inherited) do
    Enum.flat_map(children, &node_to_block(&1, style || inherited))
  end

  defp node_to_block(%RenderNode{type: :stack, children: children}, inherited) do
    Enum.flat_map(children, &node_to_block(&1, inherited))
  end

  defp node_to_block(_other, _inherited), do: []

  # Place blocks side by side: pad each to the tallest block's line count and to its
  # own widest line, then concatenate segments row by row.
  defp zip_horizontal([]), do: []
  defp zip_horizontal([single]), do: single

  defp zip_horizontal(blocks) do
    height = blocks |> Enum.map(&length/1) |> Enum.max()

    padded =
      Enum.map(blocks, fn block ->
        width = block |> Enum.map(&line_width/1) |> Enum.max(fn -> 0 end)

        Enum.map(0..(height - 1)//1, fn row ->
          line = Enum.at(block, row, [])
          pad = width - line_width(line)
          if pad > 0, do: line ++ [{String.duplicate(" ", pad), nil}], else: line
        end)
      end)

    padded
    |> Enum.zip_with(& &1)
    |> Enum.map(&Enum.concat/1)
  end

  defp line_width(segments) do
    Enum.reduce(segments, 0, fn {text, _style}, acc -> acc + String.length(text) end)
  end

  defp line_to_string(segments) do
    Enum.map_join(segments, "", fn {text, style} -> apply_style(text, style) end)
  end

  # --- styling -------------------------------------------------------------

  defp apply_style(text, nil), do: text

  defp apply_style(text, %{} = style) do
    fg = Map.get(style, :fg)
    attrs = style |> Map.get(:attrs, MapSet.new()) |> Enum.to_list()

    params =
      [TermUI.SGR.color_param(:fg, fg) | Enum.map(attrs, &TermUI.SGR.attr_param/1)]
      |> Enum.reject(&is_nil/1)

    wrap(text, params)
  end

  defp ansi(text, color, attrs \\ []) do
    params =
      [TermUI.SGR.color_param(:fg, color) | Enum.map(attrs, &TermUI.SGR.attr_param/1)]
      |> Enum.reject(&is_nil/1)

    wrap(text, params)
  end

  defp wrap(text, []), do: text
  defp wrap(text, params), do: "\e[" <> Enum.join(params, ";") <> "m" <> text <> "\e[0m"

  defp format_number(value) when is_float(value), do: Float.to_string(Float.round(value, 2))
  defp format_number(value), do: to_string(value)

  # --- output --------------------------------------------------------------

  # Join the non-nil parts and either wrap for Livebook or hand back the raw string.
  defp output(parts, opts) do
    text =
      parts
      |> Enum.reject(&(is_nil(&1) or &1 == ""))
      |> Enum.join("\n")

    case Keyword.get(opts, :as, :kino) do
      :string -> text
      :kino -> to_kino(text)
    end
  end

  defp to_kino(text) do
    if Code.ensure_loaded?(Kino.Text) do
      Kino.Text.new(text, terminal: true)
    else
      text
    end
  end
end
