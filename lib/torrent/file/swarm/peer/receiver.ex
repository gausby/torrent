defmodule Torrent.File.Swarm.Peer.Receiver do
  use GenServer

  alias :gen_tcp, as: TCP

  defstruct(
    socket: nil
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
      :ok <- GenServer.call(receiver_pid, {:set_socket, socket}),
      :ok <- TCP.controlling_process(socket, receiver_pid),
      :ok <- set_readable(socket),
      do: :ok
    )
  end

  defp set_readable(socket),
    do: :inet.setopts(socket, active: :once)

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_call({:set_socket, socket}, _from, state) do
    {:reply, :ok, %State{state|socket: socket}}
  end

  def handle_info({:tcp, _port, message}, %State{socket: socket} = state) do
    IO.inspect PeerWire.decode_message(message)
    set_readable(socket)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _port}, state) do
    IO.inspect "closing"
    {:stop, :normal, state}
  end
end
