defmodule Tracker.File.Peer.State do

  defstruct downloaded: nil, uploaded: nil, left: nil

  def start_link(trackerid) do
    Agent.start_link(&init/0, name: via_name(trackerid[:info_hash], trackerid[:trackerid]))
  end

  defp via_name(info_hash, trackerid),
    do: {:via, :gproc, peer_name(info_hash, trackerid)}
  defp peer_name(info_hash, trackerid),
    do: {:n, :l, {__MODULE__, info_hash, trackerid}}

  def init do
    %__MODULE__{}
  end

  def update(info_hash, trackerid, %{"left" => left, "downloaded" => downloaded, "uploaded" => uploaded}) do
    Agent.update(via_name(info_hash, trackerid), fn state ->
      %__MODULE__{state|left: left, downloaded: downloaded, uploaded: uploaded}
    end)
  end
  # received malformed data, should perhaps just crash
  def update(_info_hash, _trackerid, %{}),
    do: :ok

  def get(info_hash, trackerid) do
    Agent.get(via_name(info_hash, trackerid), fn s -> s end)
  end
end
