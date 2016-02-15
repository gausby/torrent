defmodule Torrent.File.Pieces.Store.Blocks.Block do
  defstruct [:candidates, :offset, :length, :info_hash, :piece_number]

  alias __MODULE__, as: State

  def start_link(info_hash, piece_number, offset, length) do
    initial_state =
      %State{info_hash: info_hash,
             piece_number: piece_number,
             offset: offset,
             length: length,
             candidates: []}

    Agent.start(fn -> initial_state end, name: via_name({info_hash, piece_number, offset, length}))
  end

  defp via_name({info_hash, piece_number, offset, length}),
    do: {:via, :gproc, block_name({info_hash, piece_number, offset, length})}
  defp block_name({info_hash, piece_number, offset, length}),
    do: {:n, :l, {__MODULE__, info_hash, piece_number, offset, length}}

  def add_candidate(block, {candidate, data}) do
    Agent.update(via_name(block), fn state ->
      %State{state|candidates: [{candidate, data} | state.candidates]}
    end)
  end

  def get_candidates(block) do
    Agent.get(via_name(block), fn state -> state.candidates end)
  end
end
