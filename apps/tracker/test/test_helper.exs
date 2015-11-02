ExUnit.start()

defmodule TrackerTest.Request do
  @moduledoc """
  This module is used to ensure the test data, send to the tracker
  implementation follows the conventions for an announce.
  """
  defstruct info_hash: nil,
            peer_id: "xxxxxxxxxxxxxxxxxxxx",
            port: 31337, # typically 6881..6889
            uploaded: 0,
            downloaded: 0,
            left: 700,
            compact: nil, # 1 or 0
            no_peer_id: nil, # ignored if compact is enabled
            event: nil, # started, stopped, completed
            # optional
            ip: nil, # will default to the clients ip
            numwant: nil,
            key: nil,
            trackerid: nil # should be set on second announce

  def create() do
    %__MODULE__{}
  end

end
