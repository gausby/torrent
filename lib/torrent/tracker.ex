defmodule Torrent.Tracker do
  use Application
  use Plug.Router

  def start(_type, args) do
    Plug.Adapters.Cowboy.http __MODULE__, [], args
  end

  def stop(_state) do
    Plug.Adapters.Cowboy.shutdown __MODULE__.HTTP
  end

  plug Plug.Logger
  plug :match
  plug :dispatch

  @data "hello"

  get "announce" do
    send_resp(conn, 200, Bencode.encode(@data))
  end

  match _ do
    send_resp(conn, 404, "file not found")
  end
end
