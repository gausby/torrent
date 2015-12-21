defmodule PeerWire.Acceptor do
  use Supervisor

  def start_link(peer_id, port) do
    with(
      {:ok, pid} <- Supervisor.start_link(__MODULE__, [port: port, peer_id: peer_id], name: __MODULE__),
      {:ok, _} <- start_socket(),
      do: {:ok, pid}
    )
  end

  def init(opts) do
    {:ok, listen_socket} = :gen_tcp.listen(opts[:port], [:binary, active: false, reuseaddr: true])
    children = [
      worker(PeerWire.Peer, [listen_socket, opts[:peer_id]])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_socket do
    Supervisor.start_child(__MODULE__, [])
  end
end

defmodule PeerWire.Peer do
  use GenServer
  alias :gen_tcp, as: TCP

  defstruct socket: nil, peer_id: nil
  alias PeerWire.Peer, as: State

  # Client API
  def start_link(accept_socket, peer_id) do
    GenServer.start_link(__MODULE__, [accept_socket, peer_id])
  end

  # Server callbacks
  def init([accept_socket, peer_id]) do
    GenServer.cast(self(), :accept)
    {:ok, %State{socket: accept_socket, peer_id: peer_id}}
  end

  # accept a connection and start a new acceptor
  def handle_cast(:accept, %State{socket: accept_socket} = state) do
    case TCP.accept(accept_socket) do
      {:ok, socket} ->
        handle_handshake(socket, state)

      _ = message ->
        IO.inspect {:failure_accepting_connection, message}
    end
    {:ok, _pid} = PeerWire.Acceptor.start_socket()
    {:stop, :normal, state}
  end

  defp handle_handshake(socket, state) do
    # todo, make somekind of throttler so we don't connect to the entire world.
    # thirty-five connected peers should be enough according to the specs.
    with(
      {:ok, {ip, port}} <- :inet.peername(socket),
      {:ok, info_hash, peer_id} <- PeerWire.PeerWire.receive_handshake(socket),
      :ok <- integrity_check(%{peer_id: peer_id, ip: ip, port: port, info_hash: info_hash}, state),
      # spawn a process and complete the handshake
      do: TCP.send(socket, [info_hash, state.peer_id])
    )
  end

  defp integrity_check(remote, state) do
    with(
      :ok <- check_info_hash(remote[:info_hash]),
      :ok <- check_peer_id(remote[:peer_id], state.peer_id),
      :ok <- check_ip_and_port({remote[:ip], remote[:port]}),
      # check if ip and port is on the naughty-list
      do: :ok
    )
  end

  defp check_info_hash(_info_hash),
    # todo, check if we have a swarm controller registered with the given info_hash
    do: :ok

  defp check_peer_id(same, same),
    do: {:error, "connecting to self"}
  defp check_peer_id(_, _),
    do: :ok

  defp check_ip_and_port(_addr) do
    :ok
  end
end


defmodule PeerWire.PeerWire do
  alias :gen_tcp, as: TCP
  @protocol "BitTorrent Protocol"
  @protocol_length byte_size @protocol

  def local_capabilities() do
    <<0, 0, 0, 0, 0, 0, 0, 0>>
  end
  def protocol_header(capabilities) do
    [@protocol_length, @protocol, capabilities]
  end

  def receive_handshake(socket) do
    with(
      capabilities = local_capabilities(),
      initial_handshake = protocol_header(capabilities),
      :ok <- TCP.send(socket, initial_handshake),
      {:ok, <<@protocol_length, @protocol, capabilities::binary-size(8),
              info_hash::binary-size(20), peer_id::binary-size(20)>>} <- TCP.recv(socket, 68, 5000),

      do: {:ok, info_hash, peer_id}
    )
  end
end


defmodule PeerWire.Client do
  use Connection

  defstruct(
    peerid: nil,
    socket: nil
  )

  @choke 0
  @unchoke 1
  @interested 2
  @not_interested 3
  @have 4
  @bitfield 5
  @request 6
  @piece 7
  @cancel 8

  #=Client API =========================================================
  def start_link do
    Connection.start_link(__MODULE__, %__MODULE__{})
  end

  #=Messages -----------------------------------------------------------
  @doc """
  Send interested to the remote peer
  """
  def interested(pid),
    do: GenServer.cast(pid, {:message, :interested})

  @doc """
  Send not interested to the remote peer
  """
  def not_interested(pid),
    do: GenServer.cast(pid, {:message, :not_interested})

  @doc """
  Send cancel to the remote peer
  """
  def cancel(pid),
    do: GenServer.cast(pid, {:message, :cancel})

  @doc """
  Send choke to the remote peer
  """
  def choke(pid),
    do: GenServer.cast(pid, {:message, :choke})

  @doc """
  Send unchoke to the remote peer
  """
  def unchoke(pid),
    do: GenServer.cast(pid, {:message, :unchoke})

  #=Server callbacks ===================================================
  def init(state) do
    {:connect, nil, state}
  end

  def connect(_info, state) do
    opts = [:binary, active: :once]
    case :gen_tcp.connect('localhost', 9000, opts) do
      {:ok, socket} ->
        {:ok, %{state|socket: socket}}

      {:error, _reason} ->
        {:backoff, 1000, state} # todo, implement proper backoff strategy
    end
  end

  def disconnect(_info, %{socket: socket} = state) do
    :gen_tcp.close(socket)
    {:stop, :normal, state}
  end

  def handle_cast({:message, type}, %{socket: socket} = state) do
    case type do
      # @have 4
      # @bitfield 5
      # @request 6
      # @piece 7
      :interested ->
        :gen_tcp.send(socket, <<@interested>>)
        {:noreply, state}

      :not_interested ->
        :gen_tcp.send(socket, <<@not_interested>>)
        {:noreply, state}

      :choke ->
        :gen_tcp.send(socket, <<@choke>>)
        {:noreply, state}

      :unchoke ->
        :gen_tcp.send(socket, <<@unchoke>>)
        {:noreply, state}

      :cancel ->
        :gen_tcp.send(socket, <<@cancel>>)
        {:disconnect, state, state}
    end
  end

  def handle_cast(:close, state) do
    {:disconnect, state, state}
  end
end
