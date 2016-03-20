defmodule Torrent.PeerDiscovery do
  use Supervisor

  @moduledoc """
  Peer discovery handler.

  Design goals:

    - Should emit peers found on trackers and distributed hash
      tables to the torrent processes
    - Should implement a plugin architecture allowing different
      peer discovery strategies, such as DHTs, HTTP Trackers,
      etc
    - Should be able to start, stop, pause, and resume a given
      discoverer
  """

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [

    ]
    supervise(children, strategy: :one_for_one)
  end
end
