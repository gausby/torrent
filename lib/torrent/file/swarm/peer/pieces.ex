defmodule Torrent.File.Swarm.Peer.Pieces do
  def start_link(info_hash, {ip, port}) do
    Agent.start_link(initial_value(info_hash), name: via_name(info_hash, ip, port))
  end

  defp initial_value(info_hash) do
    fn -> BitFieldSet.new(64, info_hash) end
  end

  defp via_name(info_hash, ip, port),
    do: {:via, :gproc, peer_name(info_hash, ip, port)}
  defp peer_name(info_hash, ip, port),
    do: {:n, :l, {__MODULE__, info_hash, ip, port}}

  def overwrite({info_hash, {ip, port}}, set) do
    Agent.get_and_update(via_name(info_hash, ip, port), fn state ->
      target_size = state.size
      case BitFieldSet.new(set, state.info_hash) do
        %BitFieldSet{size: ^target_size} = new_state ->
          {:ok, new_state}

        _ ->
          {{:error, :set_mismatch}, state}
      end
    end)
  end

  def have({info_hash, {ip, port}}, piece) do
    Agent.update(via_name(info_hash, ip, port), BitFieldSet, :set, [piece])
  end

  def has?({info_hash, {ip, port}}, piece) do
    Agent.get(via_name(info_hash, ip, port), BitFieldSet, :member?, [piece])
  end

  def has_all?({info_hash, {ip, port}}) do
    Agent.get(via_name(info_hash, ip, port), BitFieldSet, :has_all?, [])
  end

  def status({info_hash, {ip, port}}) do
    Agent.get(via_name(info_hash, ip, port), &(&1))
  end
end
