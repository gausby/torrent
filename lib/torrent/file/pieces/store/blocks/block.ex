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
             candidates: %{},
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
    data_sha = :crypto.hash(:sha, data)
    candidates =
      if Map.has_key?(current, data_sha) do
        update_in(current, [data_sha], fn {data, providers} ->
          {data, MapSet.put(providers, provider)}
        end)
      else
        Controller.report_block(state.controller, {:has, state.offset})
        Map.put_new(current, data_sha, {data, MapSet.new([provider])})
      end

    {:noreply, %State{state|candidates: candidates}}
  end

  def handle_call(:candidates, _from, state) do
    {:reply, state.candidates, state}
  end
end
