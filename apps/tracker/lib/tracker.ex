defmodule Tracker do
  @behaviour Plug
  import Plug.Conn
  import Tracker.Utils, only: [to_scrape_path: 1]

  def init(opts) do
    # The scrape path will be found relative to the announce path.
    # This will fail if the annonuce path is invalid
    {:ok, scrape_path} = to_scrape_path(opts[:path])

    Keyword.merge(opts, [announce: opts[:path], scrape: scrape_path])
  end

  def call(%Plug.Conn{method: "GET"} = conn, opts) do
    cond do
      conn.request_path == opts[:announce] ->
        conn |> halt |> handle_announce

      conn.request_path == opts[:scrape] ->
        conn |> halt |> handle_scrape

      :otherwise ->
        conn
    end
  end
  # let other request methods pass through...
  def call(conn, _),
    do: conn

  defp handle_announce(%Plug.Conn{} = conn) do
    conn = conn |> Plug.Conn.fetch_query_params
    response = %{peers: []}
    send_resp(conn, 200, Bencode.encode(response))
  end

  defp handle_scrape(%Plug.Conn{} = conn) do
    case get_info_hashes(conn) do
      [] ->
        send_resp conn, 200, Bencode.encode(%{files: []})

      info_hashes ->
        files = Enum.reduce(info_hashes, %{}, fn(info_hash, acc) ->
          # there is a name key which is optional
          status = %{complete: 0, downloaded: 0, incomplete: 0}
          Map.put_new(acc, info_hash, status)
        end)
        send_resp conn, 200, Bencode.encode(%{files: files})
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
end
