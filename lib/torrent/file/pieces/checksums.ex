defmodule Torrent.File.Pieces.Checksums do
  # this module could perhaps be replaced by an ETS table

  @moduledoc """
  Hold the checksums for all the pieces in a given torrent.
  """

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

  defp via_name(info_hash),
    do: {:via, :gproc, checksum_index(info_hash)}
  defp checksum_index(info_hash),
    do: {:n, :l, {__MODULE__, info_hash}}

  @doc """
  Get the checksum for a given piece index. Takes an integer as
  the piece index and will return nil if a number out of range
  is requested.
  """
  def get(pid, index) when is_pid(pid),
    do: Agent.get(pid, Map, :get, [index])
  def get(info_hash, index),
    do: Agent.get(via_name(info_hash), Map, :get, [index])

  defp split_into_indexed_pieces(pieces, index \\ 0, acc \\ [])
  defp split_into_indexed_pieces(<<>>, _index, acc),
    do: Enum.reverse(acc)
  defp split_into_indexed_pieces(<<piece::binary-size(20), pieces::binary>>, index, acc),
    do: split_into_indexed_pieces(pieces, index + 1, [{index, piece}|acc])
end
