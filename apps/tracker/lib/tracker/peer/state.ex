defmodule Tracker.Peer.State do
  @moduledoc """
  This is a struct that contain all the info we want to keep on a connected peer.
  """

  defstruct [
    info_hash: nil,
    complete: false,
    peer_id: nil,
    uploaded: 0, downloaded: 0, left: 0,
    ip: nil,
    port: nil,
    trackerid: nil,
    key: nil]
end
