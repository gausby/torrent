defmodule Torrent.File.Pieces.Store.Controller do
  @behaviour :gen_fsm

  require Logger

  alias Torrent.File.Pieces.Store.Blocks
  alias __MODULE__, as: State

  defstruct [:info_hash, :index, :piece_length, :block_length, :blocks, :has, :checksum]

  def start_link(info_hash, meta_info, piece_index, <<checksum::binary-size(20)>>, block_length) do
    piece_length = meta_info["piece length"]
    blocks = div(piece_length, block_length) + (if rem(piece_length, block_length) == 0, do: 0, else: 1)
    initial_state =
      %State{info_hash: info_hash,
             index: piece_index,
             piece_length: piece_length,
             blocks: blocks,
             has: MapSet.new(),
             block_length: block_length,
             checksum: checksum}

    :gen_fsm.start_link(__MODULE__, initial_state, [])
  end

  # public api
  def report_block(pid, {:has, count}) do
    :gen_fsm.send_event(pid, {:has, count})
  end

  # states
  def awaiting_blocks({:has, offset}, state) do
    new_state = %State{state|has: MapSet.put(state.has, offset)}
    if MapSet.size(new_state.has) == state.blocks do
      :gen_fsm.send_event(self, :validate)
      {:next_state, :validating_piece, new_state}
    else
      {:next_state, :awaiting_blocks, new_state}
    end
  end
  def awaiting_blocks(message, state) do
    Logger.info "Received an unknown message #{inspect message} in the awaiting_blocks state"
    {:next_state, :awaiting_blocks, state}
  end

  def validating_piece(:validate, state) do
    # this implementation fetches the first candidate from a block store and discard all other
    # info. This need to get replaced with the actual implementation
    candidates =
      for {offset, length} <- split_length_into_blocks(state.piece_length, state.block_length) do
        block = {state.info_hash, state.index, offset, length}
        Blocks.Block.get_candidates(block) |> Map.values |> hd |> elem(0)
      end

    piece_data = Enum.join(candidates)

    if :crypto.hash(:sha, piece_data) == state.checksum do
      :gen_fsm.send_event(self, :complete)
      {:next_state, :got_piece, state}
    else
      # todo, start listening for new candidates
      # todo, send orders to peers for new candidates
      {:next_state, :validating_piece, state}
    end
  end
  def validating_piece(message, state) do
    Logger.info "Received an unknown message #{inspect message} in the validating_piece state"
    {:next_state, :validating_piece, state}
  end

  def got_piece(:complete, state) do
    # todo, store the valid data to disk and clean up
    {:next_state, :got_piece, state}
  end
  def got_piece(message, state) do
    Logger.info "Received an unknown message #{inspect message} in the got_piece state"
    {:next_state, :got_piece, state}
  end

  # todo, check the received blocks when all has arrived, concat them and run the checksum
  # todo, save data to disk
  # todo, when checksum is passed it should close down and clean up after all processes

  # gen_fsm callbacks
  def init(state) do
    # spawn block processes for all the blocks in the piece
    for {offset, length} <- split_length_into_blocks(state.piece_length, state.block_length) do
      Blocks.add(state.info_hash, state.index, offset, length)
    end

    {:ok, :awaiting_blocks, state}
  end

  def handle_info(_, _state_name, state) do
    {:stop, :unexpected_message, state}
  end

  def handle_event(_, _state_name, state) do
    {:stop, :unexpected_event, state}
  end

  def handle_sync_event(_event, _from, _state_name, state) do
    {:stop, :unexpected_event, state}
  end

  def code_change(_old_version, state_name, state, _extra) do
    {:ok, state_name, state}
  end

  def terminate(reason, _state_name, _state) do
    reason
  end

  # =====================================================================
  defp split_length_into_blocks(remaining, piece_length, offset \\ 0, acc \\ [])
  defp split_length_into_blocks(0, _, _, acc) do
    Enum.reverse(acc)
  end
  defp split_length_into_blocks(remaining, piece_length, offset, acc) when piece_length < remaining do
    split_length_into_blocks(remaining - piece_length, piece_length, offset + piece_length, [{offset, piece_length}|acc])
  end
  defp split_length_into_blocks(remaining, piece_length, offset, acc) do
    split_length_into_blocks(0, piece_length, offset + piece_length, [{offset, remaining}|acc])
  end
end
