defmodule Torrent.File.Pieces.Store do
  use Supervisor

  #
  def start_link(info_hash, meta_info) do
    Supervisor.start_link(__MODULE__, meta_info, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, store_name(info_hash)}
  defp store_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init(meta_info) do
    children = [
      supervisor(Torrent.File.Pieces.Store.Blocks, []),
      worker(Torrent.File.Pieces.Store.Checksums, [meta_info["pieces"]]),
      worker(Torrent.File.Pieces.Store.Controller, [Map.take(meta_info, ["piece length"])])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
