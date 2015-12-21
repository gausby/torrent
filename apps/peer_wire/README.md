# PeerWire

Work in progress implementation of the Bittorrent Peer Wire Protocol.

- [ ] Accept incoming communication, forward to connection to a regular process

- [ ] Handshake

- [ ] send choke

- [ ] receive choke

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add peer_wire to your list of dependencies in `mix.exs`:

        def deps do
          [{:peer_wire, "~> 0.0.1"}]
        end

  2. Ensure peer_wire is started before your application:

        def application do
          [applications: [:peer_wire]]
        end
