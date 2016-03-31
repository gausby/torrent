defmodule Torrent.File do
  use Supervisor

  @moduledoc """
  A supervisor that hold the top-level processes running in a torrent
  process.

    - *Torrent.File.Swarm* is a supervisor that hold processes related
      to connected peers for the given torrent.
    - *Torrent.File.Pieces* is a supervisor that keep track of which
      pieces has been downloaded and which pieces are pending.
    - *Torrent.File.Controller* is a process that should be used to
      request information from, and give orders to, the swarm and
      pieces processes.
  """

  def start_link(peer_id, info_hash, meta) do
    Supervisor.start_link(__MODULE__, {peer_id, info_hash, meta}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init({peer_id, info_hash, meta}) do
    children = [
      supervisor(Torrent.File.Swarm, [info_hash, meta["info"]]),
      supervisor(Torrent.File.Pieces, [info_hash, meta["info"]]),
      worker(Torrent.File.Controller, [peer_id, info_hash, meta])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
