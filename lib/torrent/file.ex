defmodule Torrent.File do
  use Supervisor

  def start_link(info_hash, meta) do
    Supervisor.start_link(__MODULE__, {info_hash, meta}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init({info_hash, meta}) do
    children = [
      worker(Torrent.File.Swarm, [info_hash, meta["info"]]),
      worker(Torrent.File.Controller, [info_hash]),
      supervisor(Torrent.File.Pieces, [info_hash, meta["info"]])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
