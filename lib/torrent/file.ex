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
    meta_info =
      %{"pieces" => <<1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9,0>>,
        "piece length" => 524288,
        "length" => 1178386432}

    children = [
      worker(Torrent.File.Swarm, [info_hash]),
      worker(Torrent.File.Controller, [info_hash]),
      supervisor(Torrent.File.Pieces, [info_hash, meta_info])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
