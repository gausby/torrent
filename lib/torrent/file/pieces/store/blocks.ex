defmodule Torrent.File.Pieces.Store.Blocks do
  use Supervisor

  def start_link(info_hash, piece_number) do
    Supervisor.start_link(__MODULE__, {info_hash, piece_number}, name: via_name(info_hash, piece_number))
  end

  defp via_name(info_hash, piece_number),
    do: {:via, :gproc, block_controller_name(info_hash, piece_number)}
  defp block_controller_name(info_hash, piece_number),
    do: {:n, :l, {__MODULE__, info_hash, piece_number}}

  def init({info_hash, piece_number}) do
    children = [
      worker(Torrent.File.Pieces.Store.Blocks.Block, [info_hash, piece_number])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(info_hash, piece_number, offset, length) do
    case :gproc.where(block_controller_name(info_hash, piece_number)) do
      :undefined ->
        nil

      pid ->
        Supervisor.start_child(pid, [offset, length, self])
    end
  end
end
