defmodule Torrent.File.Swarm.Peer.Receiver do
  use GenServer

  alias :gen_tcp, as: TCP

  defstruct(
    socket: nil,
    state: :initializing
  )
  alias Torrent.File.Swarm.Peer.Receiver, as: State

  # Client API
  def start_link(info_hash, {ip, port}) do
    GenServer.start_link(__MODULE__, %State{socket: nil}, name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def hand_socket({info_hash, peer}, socket) do
    with(
      {ip, port} = peer,
      receiver_pid = :gproc.where(peer_name(info_hash, ip, port)),
      :ok <- TCP.controlling_process(socket, receiver_pid),
      :ok <- GenServer.call(receiver_pid, {:set_socket, socket}),
      :ok <- GenServer.call(receiver_pid, :set_readable),
      do: :ok
    )
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_call({:set_socket, socket}, _from, state) do
    {:reply, :ok, %State{state|socket: socket}}
  end

  def handle_call(:set_readable, _from, %State{socket: socket} = state) do
    :inet.setopts(socket, [active: false])
    {:reply, :ok, state}
  end
end
