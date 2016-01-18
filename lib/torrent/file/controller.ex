defmodule Torrent.File.Controller do
  use GenServer

  @moduledoc """
  Process level controller. Should react to events send from the peer controllers.
  """

  # Client API
  def start_link(info_hash) do
    GenServer.start_link(__MODULE__, :ok, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, controller_name(info_hash)}
  defp controller_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  # Server callbacks
  def init(state) do
    {:ok, state}
  end
end
