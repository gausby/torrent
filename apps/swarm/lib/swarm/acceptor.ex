defmodule Swarm.Acceptor do
  use Supervisor
  alias :gen_tcp, as: TCP

  def start_link(peer_id, port) do
    with(
      {:ok, pid} <- Supervisor.start_link(__MODULE__, [port: port, peer_id: peer_id], name: via_name(peer_id)),
      {:ok, _} <- start_socket(pid),
      do: {:ok, pid}
    )
  end

  defp via_name(peer_id),
    do: {:via, :gproc, acceptor_name(peer_id)}
  defp acceptor_name(peer_id),
    do: {:n, :l, {__MODULE__, peer_id}}

  def init(opts) do
    {:ok, listen_socket} = TCP.listen(opts[:port], [:binary, active: false, reuseaddr: true])
    children = [
      worker(Swarm.Acceptor.Peer, [listen_socket, opts[:peer_id]])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_socket(peer_id) when is_pid(peer_id),
    do: Supervisor.start_child(peer_id, [])
  def start_socket(peer_id),
    do: Supervisor.start_child(via_name(peer_id), [])
end
