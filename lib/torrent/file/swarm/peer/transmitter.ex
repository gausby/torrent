defmodule Torrent.File.Swarm.Peer.Transmitter do
  use GenServer

  # Client API
  def start_link(info_hash, {ip, port}) do
    GenServer.start_link(__MODULE__, %{socket: nil}, name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def hand_socket({info_hash, {ip, port}}, socket) do
    GenServer.cast(via_name(info_hash, ip, port), {:set_socket, socket})
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:set_socket, socket}, state) do
    {:noreply, %{state|socket: socket}}
  end
end
