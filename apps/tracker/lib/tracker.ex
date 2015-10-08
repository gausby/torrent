defmodule Tracker do
  use Application
  use Plug.Router

  def start(_, args) do
    Plug.Adapters.Cowboy.http __MODULE__, [], args
  end

  def stop(_) do
    Plug.Adapters.Cowboy.shutdown __MODULE__.HTTP
  end

  plug :match
  plug :dispatch

  @data "hello, world!"
  get "announce" do
    send_resp conn, 200, Bencode.encode(@data)
  end

  get "scrape" do
    case get_info_hashes(conn) do
      [] ->
        send_resp conn, 200, Bencode.encode("all")

      info_hashes ->
        send_resp conn, 200, Bencode.encode(info_hashes)
    end
  end

  # Creating a custom query string parser specificly for info_hash-values,
  # as the default query parser will return a map, resulting in only the
  # last given info_hash being send as it is overwritten everytime it sees
  # a info_hash in the query_string.
  #
  # this is a problem because some clients will ask for stuff like:
  #   /scrape?info_hash=foo&info_hash=bar
  defp get_info_hashes(%Plug.Conn{} = conn) do
    conn.query_string
    |> String.split("&")
    |> Enum.filter_map(&info_hash?/1, &extract_info_hash/1)
  end

  defp info_hash?(topic),
    do: String.starts_with? topic, "info_hash="

  defp extract_info_hash(<<"info_hash=", info_hash::binary>>),
    do: info_hash

  match _ do
    send_resp conn, 404, "File not found"
  end
end
