defmodule Torrent.File do
  use Supervisor

  def start_link(info_hash) do
    Supervisor.start_link(__MODULE__, info_hash, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, file_name(info_hash)}
  defp file_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init(info_hash) do
    children = [
      worker(Torrent.File.Swarm, [info_hash])
    ]
    supervise(children, strategy: :one_for_one)
  end

end

defmodule Torrent.File.Supervisor do
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

  def add(info_hash) do
    Supervisor.start_child(__MODULE__, [info_hash])
  end
end
