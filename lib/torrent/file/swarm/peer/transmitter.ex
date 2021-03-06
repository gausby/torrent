defmodule Torrent.File.Swarm.Peer.Transmitter do
  use GenServer

  alias :gen_tcp, as: TCP
  alias __MODULE__, as: State

  defstruct(
    socket: nil
  )

  # Client API
  def start_link(info_hash, {ip, port}) do
    GenServer.start_link(__MODULE__, %State{}, name: via_name(info_hash, ip, port))
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def hand_socket({info_hash, {ip, port}}, socket) do
    GenServer.cast(via_name(info_hash, ip, port), {:set_socket, socket})
  end

  @doc """
  Choke the remote peer.

  This tells the remote peer that they should not expect any data from us, except for
  an eventual *unchoke*-message.
  """
  def choke(pid) when is_pid(pid),
    do: GenServer.cast(pid, :choke)
  def choke(info_hash, {ip, port}),
    do: GenServer.cast(via_name(info_hash, ip, port), :choke)

  @doc """
  Stop chocking the remote peer.

  This tells the remote peer that we will stop choking them, and that they can expect
  data coming from our end.
  """
  def unchoke(pid) when is_pid(pid),
    do: GenServer.cast(pid, :unchoke)
  def unchoke(info_hash, {ip, port}),
    do: GenServer.cast(via_name(info_hash, ip, port), :unchoke)

  @doc """
  Inform the remote peer that we are interested in pieces of data that they currently
  claim to have in their possession.
  """
  def interested(pid) when is_pid(pid),
    do: GenServer.cast(pid, :interested)
  def interested(info_hash, {ip, port}),
    do: GenServer.cast(via_name(info_hash, ip, port), :interested)

  @doc """
  Inform the remote peer that we are not interested in any pieces of data that they
  claim to have in their possession.
  """
  def not_interested(pid) when is_pid(pid),
    do: GenServer.cast(pid, :not_interested)
  def not_interested(info_hash, {ip, port}),
    do: GenServer.cast(via_name(info_hash, ip, port), :not_interested)

  @doc """
  Inform the remote peer that we are in the possession of the given piece number.
  """
  def have(pid, piece_number) when is_pid(pid),
    do: GenServer.cast(pid, {:have, piece_number})
  def have({info_hash, {ip, port}}, piece_number),
    do: GenServer.cast(via_name(info_hash, ip, port), {:have, piece_number})

  @doc """
  Send the current bitfield to the remote peer.
  """
  def bitfield(pid, bitfield) when is_pid(pid),
    do: GenServer.cast(pid, {:bitfield, bitfield})
  def bitfield({info_hash, {ip, port}}, bitfield),
    do: GenServer.cast(via_name(info_hash, ip, port), {:bitfield, bitfield})

  # Server callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:set_socket, socket}, state) do
    {:noreply, %State{state|socket: socket}}
  end

  def handle_cast(:choke, %State{socket: socket} = state) do
    TCP.send(socket, <<1::big-integer-size(32), 0>>)
    {:noreply, state}
  end

  def handle_cast(:unchoke, %State{socket: socket} = state) do
    TCP.send(socket, <<1::big-integer-size(32), 1>>)
    {:noreply, state}
  end

  def handle_cast(:interested, %State{socket: socket} = state) do
    TCP.send(socket, <<1::big-integer-size(32), 2>>)
    {:noreply, state}
  end

  def handle_cast(:not_interested, %State{socket: socket} = state) do
    TCP.send(socket, <<1::big-integer-size(32), 3>>)
    {:noreply, state}
  end

  def handle_cast({:have, piece_number}, %State{socket: socket} = state) do
    TCP.send(socket, <<1::big-integer-size(32), 4, piece_number>>)
    {:noreply, state}
  end

  def handle_cast({:bitfield, bitfield}, %State{socket: socket} = state) do
    field = BitFieldSet.to_binary(bitfield)
    field_size = byte_size(field) + 1
    message = IO.iodata_to_binary [<<field_size::big-integer-size(32), 5>>, field]
    TCP.send(socket, message)
    {:noreply, state}
  end
end
