defmodule Torrent do
  use Application

  def start(_type, _args) do
    Torrent.Supervisor.start_link
  end
end
