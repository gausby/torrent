defmodule Torrent.File.Pieces.State do
  def start_link(info_hash) do
    Agent.start_link(initial_value(info_hash), name: via_name(info_hash))
  end

  defp initial_value(info_hash) do
    fn -> BitFieldSet.new!(<<>>, 640, info_hash) end
  end

  defp via_name(info_hash),
    do: {:via, :gproc, piece_manager_name(info_hash)}
  defp piece_manager_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def overwrite(info_hash, set) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      target_size = state.size
      case BitFieldSet.new!(set, 640, state.info_hash) do
        %BitFieldSet{size: ^target_size} = new_state ->
          {:ok, new_state}

        _ ->
          {{:error, :set_mismatch}, state}
      end
    end)
  end

  def have(info_hash, piece) do
    Agent.update(via_name(info_hash), BitFieldSet, :set, [piece])
  end

  def has?(info_hash, piece) do
    Agent.get(via_name(info_hash), BitFieldSet, :member?, [piece])
  end

  def has_all?(info_hash) do
    Agent.get(via_name(info_hash), BitFieldSet, :has_all?, [])
  end

  def status(info_hash) do
    Agent.get(via_name(info_hash), &(&1))
  end
end
