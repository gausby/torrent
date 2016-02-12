defmodule Torrent.File.Pieces.Store.Blocks do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Torrent.File.Pieces.Store.Blocks.Block, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end


end
