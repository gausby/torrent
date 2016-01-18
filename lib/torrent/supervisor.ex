defmodule Torrent.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  # hard coded for now
  @peer_id "xxxxxxxxxxxxxxxxxxxx"
  @port 29182

  def init(:ok) do
    children = [
      worker(Torrent.Acceptor, [@peer_id, @port]),
      worker(Torrent.Processes, []),
      worker(Torrent.Controller, [])
    ]
    supervise(children, strategy: :one_for_one)
  end

end
