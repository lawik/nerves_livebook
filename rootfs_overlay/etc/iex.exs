try do
  NervesMOTD.print()
catch
  kind, reason -> IO.puts("MOTD unavailable: #{Exception.format(kind, reason)}")
end

# Add Toolshed helpers to the IEx session
use Toolshed

# Let deferred application starts proceed now that the shell is up
if Code.ensure_loaded?(BootPreload), do: BootPreload.shell_ready()
