defmodule Torrent.Processes do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Torrent.File, [])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(info_hash, meta) do
    Supervisor.start_child(__MODULE__, [info_hash, meta])
  end
end
