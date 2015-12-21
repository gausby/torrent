defmodule Swarm.Peers do
  use Supervisor

  def start_link(info_hash) do
    Supervisor.start_link(__MODULE__, info_hash, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init(info_hash) do
    children = [
      worker(Swarm.Peers.Peer, [info_hash])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_child(info_hash, address) do
    Supervisor.start_child(via_name(info_hash), [address])
  end
end
