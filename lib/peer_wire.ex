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
    with(
      capabilities = local_capabilities(),
      initial_handshake = protocol_header(capabilities),
      :ok <- TCP.send(socket, initial_handshake),
      {:ok, <<@protocol_length, @protocol, _capabilities::binary-size(8),
              info_hash::binary-size(20), peer_id::binary-size(20)>>} <- TCP.recv(socket, 68, 5000),

      do: {:ok, info_hash, peer_id}
    )
  end

  def complete_handshake(socket, info_hash, peer_id) do
    TCP.send(socket, [info_hash, peer_id])
  end
end
