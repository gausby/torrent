defmodule Torrent do
  use Application

  def start(_type, _args) do
    Torrent.Supervisor.start_link
  end

  def generate_peer_id() do
    random_number_stream = Stream.repeatedly(fn -> :rand.uniform(10) - 1 end)
    header = "-EX0001-"
    IO.iodata_to_binary [header, Enum.take(random_number_stream, 20 - byte_size header)]
  end
end
