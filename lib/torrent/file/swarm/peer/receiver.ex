defmodule Torrent.File.Swarm.Peer.Receiver do
  use GenServer

  alias :gen_tcp, as: TCP

  defstruct(
    state: :awaiting_socket,
    socket: nil,
    buffer: [],
    remaining: nil
  )
  alias Torrent.File.Swarm.Peer.Receiver, as: State

  #=Client API =========================================================
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
      :ok <- :inet.setopts(socket, active: :once),
      do: :ok
    )
  end

  #=Server callbacks ===================================================
  def init(state) do
    {:ok, state}
  end

  def handle_call({:set_socket, socket}, _from, %State{state: :awaiting_socket} = state) do
    {:reply, :ok, %State{state|socket: socket, state: :ready}}
  end

  def handle_info({:tcp_closed, _port}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp, socket, inbound}, state) do
    new_state = handle_inbound(inbound, state)

    :inet.setopts(socket, active: :once)
    {:noreply, new_state}
  end

  #=helpers ============================================================
  defp handle_inbound(inbound, state) do
    case do_handle_inbound(inbound, state) do
      {:scanning_for_length, data} ->
        %State{state|state: :scanning_for_length, buffer: data, remaining: nil}

      {:consuming_data, remaining, data_acc} ->
        %State{state|state: :consuming_data, buffer: data_acc, remaining: remaining}

      {:emit, package, remaining_data} ->
        # todo, send packages on to a handler process instead of stdout
        IO.inspect {:emit, package}
        handle_inbound(remaining_data, %{state|state: :ready, buffer: [], remaining: nil})

      :reset ->
        %State{state|state: :ready, buffer: [], remaining: nil}
    end
  end

  defp do_handle_inbound(<<>>, %State{state: :ready}),
    do: :reset
  # emit "alive"
  defp do_handle_inbound(<<0::big-integer-size(32), remaining::binary>>, %State{state: :ready}),
    do: {:emit, <<>>, remaining}
  # start consuming data
  defp do_handle_inbound(<<len::big-integer-size(32), remaining::binary>>, %State{state: :ready} = state),
    do: do_handle_inbound(remaining, %State{state|state: :consuming_data, remaining: len, buffer: []})

  # scanning for length ------------------------------------------------
  defp do_handle_inbound(inbound_data, %State{state: :ready})
  when byte_size(inbound_data) < 4,
    do: {:scanning_for_length, inbound_data}

  defp do_handle_inbound(<<inbound::binary>>, %State{state: :scanning_for_length, buffer: data} = state),
    # retry to see if we have enough data now
    do: do_handle_inbound(<<data::binary, inbound::binary>>, %State{state|state: :ready, buffer: []})

  # consuming data -----------------------------------------------------
  defp do_handle_inbound(inbound, %State{state: :consuming_data, remaining: remaining, buffer: data_acc})
  when byte_size(inbound) >= remaining do
    <<data::binary-size(remaining), remaining_data::binary>> = inbound

    package =
      [data|data_acc]
      |> Enum.reverse
      |> IO.iodata_to_binary

    {:emit, package, remaining_data}
  end
  defp do_handle_inbound(inbound, %State{state: :consuming_data, remaining: remaining, buffer: data_acc}),
    do: {:consuming_data, remaining - byte_size(inbound), [inbound | data_acc]}
end
