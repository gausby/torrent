defmodule Torrent.File.Pieces.Store.Blocks.Block do
  defstruct [:controller, :candidates, :offset, :length, :info_hash, :piece_number]

  use GenServer

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

    GenServer.start_link(__MODULE__, initial_state, name: via_name({info_hash, piece_number, offset, length}))
  end

  defp via_name({info_hash, piece_number, offset, length}),
    do: {:via, :gproc, block_name({info_hash, piece_number, offset, length})}
  defp block_name({info_hash, piece_number, offset, length}),
    do: {:n, :l, {__MODULE__, info_hash, piece_number, offset, length}}

  # public api
  def add_candidate(block, {data, provider}) do
    GenServer.cast(via_name(block), {:add, data, provider})
  end

  def get_candidates(block) do
    GenServer.call(via_name(block), :candidates)
  end

  # Server callbacks ----------------------------------------------------
  def init(state) do
    {:ok, state}
  end

  def handle_cast({:add, data, provider}, %State{candidates: current} = state) do
    candidates = add_to_candidates(current, data, provider)
    if length(current) < length(candidates) do
      Controller.report_block(state.controller, {:has, length candidates})
    end

    {:noreply, %State{state|candidates: candidates}}
  end

  def handle_call(:candidates, _from, state) do
    {:reply, state.candidates, state}
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
