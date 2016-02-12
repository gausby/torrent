defmodule Torrent.File.Pieces.Store.Checksums do
  # this module could perhaps be replaced by an ETS table

  def start_link(pieces) do
    lookup_table =
      pieces
      |> split_pieces
      |> Enum.into(%{})

    Agent.start_link(fn -> lookup_table end)
  end

  def get(pid, index),
    do: Agent.get(pid, Map, :get, [index])

  defp split_pieces(pieces, index \\ 0, acc \\ [])
  defp split_pieces(<<>>, _index, acc),
    do: Enum.reverse(acc)
  defp split_pieces(<<piece::binary-size(20), pieces::binary>>, index, acc),
    do: split_pieces(pieces, index + 1, [{index, piece}|acc])
end
