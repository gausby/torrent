defmodule Tracker.File.Statistics do

  defstruct complete: 0, incomplete: 0, downloaded: 0

  def start_link(info_hash) do
    Agent.start_link(&init/0, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  defp init do
    %__MODULE__{}
  end

  defp update_cache(info_hash, state) do
    new_state = Map.put(%{}, info_hash, Map.from_struct(state))
    :gproc.set_value(file_name(info_hash), new_state)
  end

  def get(info_hash) do
    Agent.get(via_name(info_hash), fn statistics -> statistics end)
  end

  def a_peer_started(info_hash) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      new_state = %__MODULE__{state|incomplete: state.incomplete + 1}
      update_cache(info_hash, new_state)
      {:ok, new_state}
    end)
  end

  def a_peer_completed(info_hash) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      new_state =
        %__MODULE__{state|
                    incomplete: state.incomplete - 1,
                    complete: state.complete + 1,
                    downloaded: state.downloaded + 1}
      update_cache(info_hash, new_state)
      {:ok, new_state}
    end)
  end

  def an_incomplete_peer_stopped(info_hash) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      new_state = %__MODULE__{state|incomplete: state.incomplete - 1}
      update_cache(info_hash, new_state)
      {:ok, new_state}
    end)
  end

  def a_completed_peer_stopped(info_hash) do
    Agent.get_and_update(via_name(info_hash), fn state ->
      new_state = %__MODULE__{state|complete: state.complete - 1}
      update_cache(info_hash, new_state)
      {:ok, new_state}
    end)
  end

end
