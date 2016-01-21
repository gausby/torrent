defmodule Torrent.File do
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
      worker(Torrent.File.Swarm, [info_hash]),
      worker(Torrent.File.Controller, [info_hash]),
      worker(Torrent.File.Pieces, [info_hash])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
