defmodule Torrent.File.Pieces.Controller do
  use GenServer

  # communicate with file controller
  # receive piece "complete info" from piece download processes
  # update the local bitfield

  # Client API
  def start_link(info_hash) do
    GenServer.start_link(__MODULE__, nil)
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end
end
