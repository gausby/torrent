defmodule Tracker.File do
  use Supervisor

  def start_link(info_hash) do
    Supervisor.start_link(__MODULE__, info_hash, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, torrent_name(info_hash)}
  defp torrent_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init(info_hash) do
    children = [
      worker(Tracker.File.Info, [info_hash]),
      worker(Tracker.File.Statistics, [info_hash]),
      supervisor(Tracker.File.Peers, [info_hash])
    ]
    supervise(children, strategy: :one_for_one)
  end

  @supervisor Tracker
  def create(info_hash) do
    case Supervisor.start_child(@supervisor, [info_hash]) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}
    end
  end

  def remove(info_hash) do
    pid = :gproc.where({:n, :l, {Tracker.File, info_hash}})
    Supervisor.terminate_child(@supervisor, pid)
  end
end
