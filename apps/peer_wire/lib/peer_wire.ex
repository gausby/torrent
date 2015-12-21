defmodule PeerWire do
  use Application

  def start(_type, opts) do
    import Supervisor.Spec, warn: false

    <<peer_id::binary-size(20)>> = Keyword.get(opts, :peer_id, generate_random_peer_id())

    children = [
      # chunk mod
      # IO mod
      # choke mod
      # peer wire manager
      worker(PeerWire.Acceptor, [peer_id, opts[:port]])
    ]

    opts = [strategy: :one_for_one, name: PeerWire.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # This should get some love at some point
  def generate_random_peer_id() do
    client_id = "EX"
    client_version = "0001"
    rand_bytes =
      Stream.repeatedly(fn -> Integer.to_string(:rand.uniform(10) - 1) end)
      |> Enum.take(12)

      "-#{client_id}#{client_version}-#{rand_bytes}"
  end
end
