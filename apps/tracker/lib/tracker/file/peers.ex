defmodule Tracker.File.Peers do
  use Supervisor
  import UUID, only: [uuid4: 0]

  def start_link(info_hash) do
    Supervisor.start_link(__MODULE__, info_hash, name: via_name(info_hash))
  end

  defp via_name(info_hash),
    do: {:via, :gproc, supervisor_name(info_hash)}
  defp supervisor_name(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def init(opts) do
    children = [
      worker(Tracker.File.Peer, [opts])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

  def add(info_hash) do
    add(info_hash, uuid4())
  end

  def add(info_hash, trackerid) do
    {:ok, pid} = Supervisor.start_child(via_name(info_hash), [trackerid])
    {:ok, pid, trackerid}
  end
end
