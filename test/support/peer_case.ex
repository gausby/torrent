defmodule Torrent.PeerCase do
  use ExUnit.CaseTemplate

  defmacro __using__(args) do
    quote do
      alias Torrent.File.Swarm.Peer
    end
  end
end
