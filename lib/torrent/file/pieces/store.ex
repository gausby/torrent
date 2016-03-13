defmodule Torrent.File.Pieces.Store do
  use Supervisor

  #
  def start_link(info_hash, meta_info, piece_number, checksum) do
    Supervisor.start_link(__MODULE__, {info_hash, meta_info, piece_number, checksum}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, store_name(info_hash)}
  defp store_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init({info_hash, meta_info, piece_number, checksum}) do
    block_length = Map.get(meta_info, "block length", 16 * 1024)

    children = [
      supervisor(Torrent.File.Pieces.Store.Blocks, [info_hash, piece_number]),
      worker(Torrent.File.Pieces.Store.Controller, [info_hash, Map.take(meta_info, ["piece length"]), piece_number, checksum, block_length])
    ]

    supervise(children, strategy: :one_for_one)
  end
end

# ======================================================================
defmodule Torrent.File.Pieces.Store.Supervisor do
  use Supervisor

  alias Torrent.File.Pieces.Checksums

  def start_link(info_hash, meta_info) do
    Supervisor.start_link(__MODULE__, {info_hash, meta_info}, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, store_name(info_hash)}
  defp store_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init({info_hash, meta_info}) do
    children = [
      supervisor(Torrent.File.Pieces.Store, [info_hash, meta_info])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(info_hash, piece_number) do
    case Checksums.get(info_hash, piece_number) do
      <<checksum::binary-size(20)>> ->
        add(info_hash, piece_number, checksum)

      nil ->
        {:error, :out_of_bounds}
    end
  end

  def add(info_hash, piece_number, checksum) do
    case :gproc.where(store_name(info_hash)) do
      :undefined ->
        nil

      pid ->
        Supervisor.start_child(pid, [piece_number, checksum])
    end
  end
end
