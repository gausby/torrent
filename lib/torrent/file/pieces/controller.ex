defmodule Torrent.File.Pieces.Controller do
  use GenServer

  # communicate with file controller
  # receive piece complete info from piece download processes
  # update the local bitfield

  # Client API
  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  # Server callbacks
  def init(state) do
    {:ok, state}
  end
end
