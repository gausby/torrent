defmodule Tracker.Plug do
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
        conn |> halt |> Plug.Conn.fetch_query_params |> guard_announce

      conn.request_path == opts[:scrape] ->
        conn |> halt |> handle_scrape

      :otherwise ->
        conn
    end
  end
  # let other request methods pass through...
  def call(conn, _),
    do: conn

  #=ANNOUNCE ===========================================================
  defp guard_announce(%Plug.Conn{params: params} = conn) do
    case params do
      # ensure that all the required fields are set and valid
      %{"info_hash" => <<info_hash::binary-size(20)>>,
        "peer_id" => <<peer_id::binary-size(20)>>, "port" => port,
         "uploaded" => uploaded, "downloaded" => downloaded, "left" => left} ->
        announce = %{
          event: params["event"] || nil,
          info_hash: info_hash, peer_id: peer_id,
          ip: params["ip"] || conn.remote_ip, port: port,
          uploaded: uploaded, downloaded: downloaded, left: left,
          trackerid: params["trackerid"] || nil
        }
        handle_announce(conn, announce)

      _ ->
        response = %{failure_reason: "Please provide a bunch of data"}
        send_resp(conn, 400, Bencode.encode(response))
    end
  end

  defp handle_announce(conn, %{event: "started", trackerid: nil} = announce) do
    case :gproc.where({:n, :l, {Tracker.Torrent, announce.info_hash}}) do
      :undefined ->
        message = Bencode.encode(%{failure_reason: "The given info_hash is not tracked by this server"})
        send_resp(conn, 300, message)

      pid ->
        case Tracker.Torrent.add_peer(pid, announce) do
          {:ok, _pid, trackerid} ->
            # todo, send numwant peers back
            response = announce_response(trackerid)
            send_resp(conn, 200, Bencode.encode(response))

          _ ->
            send_resp(conn, 300, Bencode.encode(%{failure_reason: "Something bad happened"}))
        end
    end
  end
  defp handle_announce(conn, %{event: "started", trackerid: trackerid}) when trackerid != nil do
    message = Bencode.encode(%{failure_reason: "Tracker id must not be set when announcing with started event"})
    send_resp(conn, 300, message)
  end

  defp handle_announce(conn, %{event: "stopped"} = announce) do
    case :gproc.where({:n, :l, {Tracker.Peer, announce.trackerid, announce.info_hash}}) do
      :undefined ->
        message = Bencode.encode(%{failure_reason: "Unknown peer"})
        send_resp(conn, 300, message)

      pid ->
        Tracker.Peer.announce(pid, announce)
        # todo send zero peers back
        response = announce_response(announce.trackerid)
        send_resp(conn, 200, Bencode.encode(response))
    end
  end

  defp handle_announce(conn, %{event: "completed"} = announce) do
    case :gproc.where({:n, :l, {Tracker.Peer, announce.trackerid, announce.info_hash}}) do
      :undefined ->
        message = Bencode.encode(%{failure_reason: "Unknown peer"})
        send_resp(conn, 300, message)

      pid ->
        Tracker.Peer.announce(pid, announce)
        # todo send a list of 35-50 (or numwant) peers (without seeders!) to the peer
        response = announce_response(announce.trackerid)
        send_resp(conn, 200, Bencode.encode(response))
    end
  end

  defp handle_announce(conn, announce) do
    case :gproc.where({:n, :l, {Tracker.Peer, announce.trackerid, announce.info_hash}}) do
      :undefined ->
        message = Bencode.encode(%{failure_reason: "Unknown peer"})
        send_resp(conn, 300, message)

      pid ->
        Tracker.Peer.announce(pid, announce)
        # todo send a list of peers back
        response = announce_response(announce.trackerid)
        send_resp(conn, 200, Bencode.encode(response))
    end
  end

  defp announce_response(trackerid) do
    # todo, send peers back; and set a limit to how many peers we send back
    %{peers: [], trackerid: trackerid}
  end

  #=SCRAPE =============================================================
  defp handle_scrape(%Plug.Conn{} = conn) do
    case get_info_hashes(conn) do
      [] ->
        match = {{:n, :l, {Tracker.Torrent, :'_'}}, :'$1', :'_'}
        result = for [{:n, :l, {_, info_hash}}, pid, _] <- :gproc.select([{match, [], [:'$$']}]), into: %{} do
          Tracker.Torrent.get_statistics(pid, info_hash)
        end

        send_resp conn, 200, Bencode.encode(%{files: result})

      info_hashes ->
        files = for info_hash <- info_hashes, into: %{} do
          :gproc.where({:n, :l, {Tracker.Torrent, info_hash}})
          |> Tracker.Torrent.get_statistics(info_hash)
        end
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
