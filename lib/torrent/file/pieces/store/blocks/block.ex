defmodule Torrent.File.Pieces.Store.Blocks.Block do
  defstruct [:controller, :candidates, :offset, :length, :info_hash, :piece_number]

  alias Torrent.File.Pieces.Store.Controller
  alias __MODULE__, as: State

  def start_link(info_hash, piece_number, offset, length, controller_pid) do
    initial_state =
      %State{info_hash: info_hash,
             piece_number: piece_number,
             offset: offset,
             length: length,
             candidates: [],
             controller: controller_pid}

    Agent.start(fn -> initial_state end, name: via_name({info_hash, piece_number, offset, length}))
  end

  defp via_name({info_hash, piece_number, offset, length}),
    do: {:via, :gproc, block_name({info_hash, piece_number, offset, length})}
  defp block_name({info_hash, piece_number, offset, length}),
    do: {:n, :l, {__MODULE__, info_hash, piece_number, offset, length}}

  def add_candidate(block, {data, provider}) do
    Agent.update(via_name(block), fn %State{candidates: current} = state ->
      candidates = add_to_candidates(current, data, provider)
      if length(current) < length(candidates) do
        Controller.report_block(state.controller, {:has, length candidates})
      end
      %State{state|candidates: candidates}
    end)
  end

  def get_candidates(block) do
    Agent.get(via_name(block), fn state -> state.candidates end)
  end


  # =====================================================================
  defp add_to_candidates(candidates, data, provider) do
    if Enum.any?(candidates, fn {^data, _} -> true; _ -> false end) do
      # this piece of data is already amongst the candidates
      Enum.map(candidates, fn
        {^data, providers} ->
          {data, MapSet.put(providers, provider)}

        other ->
          other
      end)
    else
      # this piece of data is new, add it to the candidates list
      [{data, MapSet.new([provider])}|candidates]
    end
  end
end
