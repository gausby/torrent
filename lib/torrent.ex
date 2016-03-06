defmodule Torrent do
  use Application

  def start(_type, args \\ []) do
    defaults =
      [peer_id: generate_peer_id,
       port: 29182]

    defaults
    |> Keyword.merge(args)
    |> Torrent.Supervisor.start_link
  end

  def generate_peer_id() do
    random_number_stream = Stream.repeatedly(fn -> :rand.uniform(10) - 1 end)
    header = "-EX0001-"
    IO.iodata_to_binary [header, Enum.take(random_number_stream, 20 - byte_size header)]
  end

  def add(<<"d", _::binary>> = raw) do
    {:ok, data, info_hash} = Bencode.decode_with_info_hash(raw)
    Torrent.Processes.add(info_hash, data)
  end
end
