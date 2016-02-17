defmodule Torrent.File.Pieces.Store.Controller do
  @behaviour :gen_fsm

  @block_length 16 * 1024 # hard code block length of 16 bytes

  alias Torrent.File.Pieces.Store.Blocks

  defstruct [:info_hash, :index, :piece_length, :block_length, :remaining_blocks, :checksum]
  alias __MODULE__, as: State

  def start_link(info_hash, meta_info, piece_index) do
    piece_length = meta_info["piece length"]
    remaining = div(piece_length, @block_length) + (if rem(piece_length, @block_length) == 0, do: 0, else: 1)
    initial_state =
      %State{info_hash: info_hash,
             index: piece_index,
             piece_length: piece_length,
             remaining_blocks: remaining,
             block_length: @block_length}

    :gen_fsm.start_link(__MODULE__, initial_state, [])
  end

  # public api
  def report_block(pid, {:has, count}) do
    :gen_fsm.send_event(pid, {:has, count})
  end

  # states
  def awaiting_blocks({:has, _count}, state) do
    {:next_state, :awaiting_blocks, state}
  end

  # todo, awaiting blocks (decrement remaining when blocks report back, when that number
  #       reach 0 it should progress to the next state)
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
