defmodule Torrent.Processes do
  use Supervisor

  @moduledoc """
  A supervisor that holds the individual torrent processes. It is global
  so system resources can be allotted to multiple simultaneous torrents.
  """

  def start_link(peer_id) do
    Supervisor.start_link(__MODULE__, peer_id, name: __MODULE__)
  end

  def init(peer_id) do
    children = [
      worker(Torrent.File, [peer_id])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(info_hash, meta) do
    Supervisor.start_child(__MODULE__, [info_hash, meta])
  end
end
