defmodule Tracker do
  use Application
  use Supervisor
  require Logger

  def start(_type, _args) do
    __MODULE__.start_link
  end

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    children = [
      worker(Tracker.File, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
