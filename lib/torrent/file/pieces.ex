defmodule Torrent.File.Pieces do
  use Supervisor

  @moduledoc """
  Piece bookkeeping.

  This is a supervisor that manage everything related to fetching
  and verifying pieces in a torrent. It manage four processes:

    - A controller, that other processes can give orders, such as
      stating that they need a certain piece number
    - A state agent that hold a bit-field representing the blocks
      of the piece that has been fetched, and which ones are not
      present yet
    - A checksum agent that hold the checksums for the individual
      pieces; when a peice has been requested a process responisble
      for getting this piece will ask for the checksum here, which
      it will use to verify the integrity of the downloaded piece
      when complete
    - A 'store' supervisor that spawn download processes of blocks
      for a given piece. The name store should probably be
      reconsidered at some point
  """

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
