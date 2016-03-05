defmodule Torrent.File.Swarm do
  use Supervisor

  def start_link(info_hash, meta) do
    Supervisor.start_link(__MODULE__, {info_hash, meta}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, swarm_name(info_hash)}
  defp swarm_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init({info_hash, meta}) do
    children = [
      worker(Torrent.File.Swarm.Peer, [info_hash, meta])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def start_child(info_hash, peer_address) do
    pid = :gproc.where(swarm_name(info_hash))
    Supervisor.start_child(pid, [peer_address])
  end
end
