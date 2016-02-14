defmodule Torrent.File.Pieces do
  use Supervisor

  def start_link(info_hash, meta_info) do
    Supervisor.start_link(__MODULE__, {info_hash, meta_info})
  end

  def init({info_hash, meta_info}) do
    children = [
      worker(Torrent.File.Pieces.Controller, [info_hash]),
      worker(Torrent.File.Pieces.State, [info_hash, Map.take(meta_info, ["piece length", "length"])]),
      worker(Torrent.File.Pieces.Checksums, [info_hash, Map.take(meta_info, ["pieces"])]),
      supervisor(Torrent.File.Pieces.Store.Supervisor, [info_hash, meta_info])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
