defmodule Torrent.Controller do
  use GenServer

  @moduledoc """
  The top most controller. Should allocate resources to the process controllers.
  """

  # Client API
  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  # Server callbacks
  def init(:ok) do
    {:ok, []}
  end

end
