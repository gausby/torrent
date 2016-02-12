defmodule Torrent.File.Pieces.Store.Blocks.Block do
  defstruct(
    candidates: [], # a canidate should be tagged with its origin, so we know which peer provided the data
    offset: 0,
    length: (16 * 1024)
  )

  def start_link(offset, length) do
    Agent.start(fn -> %__MODULE__{offset: offset, length: length} end)
  end

  # receive data
end
