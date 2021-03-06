defmodule Torrent.File.Pieces.State do
  def start_link(info_hash, %{"length" => length, "piece length" => piece_length}) do
    Agent.start_link(
      fn ->
        size = div(length, piece_length) + (if rem(length, piece_length) == 0, do: 0, else: 1)
        BitFieldSet.new!(<<>>, size, info_hash)
      end,
      name: via_name(info_hash)
    )
  end

  defp via_name(info_hash),
    do: {:via, :gproc, piece_manager_name(info_hash)}
  defp piece_manager_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def overwrite(info_hash, set) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      target_size = state.size
      case BitFieldSet.new!(set, target_size, state.info_hash) do
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
