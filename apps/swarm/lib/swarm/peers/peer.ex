defmodule Swarm.Peers.Peer do
  use GenServer
  alias :gen_tcp, as: TCP

  # Client API
  def start_link(info_hash, address) do
    GenServer.start_link(__MODULE__, address, name: via_name(info_hash, address))
  end

  defp via_name(info_hash, address),
    do: {:via, :gproc, peer_name(info_hash, address)}
  defp peer_name(info_hash, address),
    do: {:n, :l, {__MODULE__, info_hash, address}}

  @doc """

  """
  def forward_socket(pid, socket) do
    TCP.controlling_process(socket, pid)
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end
end
