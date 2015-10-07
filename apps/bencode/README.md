# Bencode

A bencode encoder/decoder for Elixir. For use for various modules in the Torrent project.

## Installation

If (and when) [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add bencode to your list of dependencies in `mix.exs`:

        def deps do
          [{:bencode, "~> 0.0.1"}]
        end

  2. Ensure bencode is started before your application:

        def application do
          [applications: [:bencode]]
        end
