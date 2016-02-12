defmodule Torrent.File.Pieces.Store.Controller do
  @behaviour :gen_fsm

  @block_length 16 * 1024 # hard code block length of 16 bytes

  defstruct(
    piece_length: nil,
    block_length: @block_length,
    remaining: 0 # how many blocks are left to completion
  )
  alias __MODULE__, as: State

  def start_link(state) do
    # IO.inspect state
    piece_length = state["piece length"]
    remaining = div(piece_length, @block_length) + (if rem(piece_length, @block_length) == 0, do: 0, else: 1)
    initial_state =
      %State{piece_length: piece_length,
             remaining: remaining}

    :gen_fsm.start_link(__MODULE__, initial_state, [])
  end

  # public api

  # states
  def idle(:idle, state) do
    {:next_state, :idle, state}
  end

  # todo, awaiting blocks (decrement remaining when blocks report back, when that number
  #       reach 0 it should progress to the next state)
  # todo, check the received blocks when all has arrived, concat them and run the checksum
  # todo, save data to disk

  # gen_fsm callbacks
  def init(state) do
    # spawn block children for all the blocks in the piece
    {:ok, :idle, state}
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
end
