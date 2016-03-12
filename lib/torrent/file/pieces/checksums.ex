defmodule Torrent.File.Pieces.Checksums do
  # this module could perhaps be replaced by an ETS table

  def start_link(info_hash, %{"pieces" => pieces}) do
    Agent.start_link(
      fn ->
        pieces
        |> split_into_indexed_pieces
        |> Enum.into(%{})
      end,
      name: via_name(info_hash)
    )
  end

  def via_name(info_hash),
    do: {:via, :gproc, checksum_index(info_hash)}
  def checksum_index(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  def get(pid, index),
    do: Agent.get(pid, Map, :get, [index])

  defp split_into_indexed_pieces(pieces, index \\ 0, acc \\ [])
  defp split_into_indexed_pieces(<<>>, _index, acc),
    do: Enum.reverse(acc)
  defp split_into_indexed_pieces(<<piece::binary-size(20), pieces::binary>>, index, acc),
    do: split_into_indexed_pieces(pieces, index + 1, [{index, piece}|acc])
end
