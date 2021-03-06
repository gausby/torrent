defmodule PeerWire do
  alias :gen_tcp, as: TCP
  @protocol "BitTorrent Protocol"
  @protocol_length byte_size @protocol

  def local_capabilities() do
    <<0, 0, 0, 0, 0, 0, 0, 0>>
  end
  def protocol_header(capabilities) do
    [@protocol_length, @protocol, capabilities]
  end

  def receive_handshake(socket) do
    capabilities = local_capabilities()
    initial_handshake = protocol_header(capabilities)
    :ok = TCP.send(socket, initial_handshake)
    {:ok, <<@protocol_length, @protocol, _capabilities::binary-size(8),
            info_hash::binary-size(20), peer_id::binary-size(20)>>} = TCP.recv(socket, 68, 5000)

    {:ok, info_hash, peer_id}
  end

  def complete_handshake(socket, info_hash, peer_id) do
    TCP.send(socket, [info_hash, peer_id])
  end

  @doc """
  Message decoding
  """
  # keep alive
  def decode_message(<<>>),
    do: :keep_alive
  # without payload
  def decode_message(<<0>>),
    do: :choke
  def decode_message(<<1>>),
    do: :unchoke
  def decode_message(<<2>>),
    do: :interested
  def decode_message(<<3>>),
    do: :not_interested
  # have
  def decode_message(<<4, piece_number::big-integer-size(32)>>),
    do: {:have, piece_number}
  # decode bitfield
  def decode_message(<<5, bitfield::binary>>) do
    {:bitfield, bitfield}
  end
  # decode request
  def decode_message(<<6, index::big-integer-size(32),
                     begin::big-integer-size(32), length::big-integer-size(32)>>) do
    {:request, index, begin, length}
  end
  # decode piece
  def decode_message(<<7, index::big-integer-size(32),
                     begin::big-integer-size(32), data::binary>>) do
    {:piece, index, begin, data}
  end
  # decode cancel
  def decode_message(<<8, index::big-integer-size(32),
                     begin::big-integer-size(32), length::big-integer-size(32)>>),
    do: {:cancel, index, begin, length}
  # todo, "port"
end
