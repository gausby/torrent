defmodule Bitfield do
  @moduledoc """
  A bit field implementation using MapSets.

  Its main usecase is for BitTorrent implementations.
  """

  defstruct(
    size: 0,
    pieces: MapSet.new,
    info_hash: nil
  )

  @doc """
  Create a new piece set given either a `size` (an integer denoting bit size)
  *or* some `content` (a binary, the size will be set from the bit size of this
  binary), and an optional `info_hash`, used to ensure only compatible
  bit-fields are compared.

      iex> Bitfield.new(16) |> Bitfield.to_binary
      <<0, 0>>

  The size will be taken from the input when a piece set is created with data:

      iex> Bitfield.new(<<128, 1>>) |> Bitfield.pieces
      [0, 15]

  The piece set can be given an `info_hash` as the second argument, it can be
  anything, and it defaults to `nil`.
  """
  def new(content, info_hash \\ nil)
  def new(content_size, info_hash) when is_number(content_size) do
    %__MODULE__{info_hash: info_hash, size: content_size, pieces: MapSet.new}
  end
  def new(content, info_hash) when is_binary(content) do
    pieces = reduce_bits(content, fn
      {index, 1}, acc ->
        [index|acc]
      _, acc ->
        acc
    end)
    %__MODULE__{info_hash: info_hash, size: bit_size(content), pieces: MapSet.new(pieces)}
  end

  # Reduce the bits in the bytes in the bit-field
  defp reduce_bits(bytes, fun),
    do: do_reduce_bits(bytes, 0, [], fun)

  defp do_reduce_bits(<<>>, _index, acc, _fun),
    do: Enum.reverse acc
  defp do_reduce_bits(<<byte::integer, rest::binary>>, index, acc, fun) do
    {index, acc} =
      number_to_padded_bits(byte)
      |> Enum.reduce({index, acc}, fn bit, {index, acc} ->
           {index + 1, fun.({index, bit}, acc)}
         end)

    do_reduce_bits(rest, index, acc, fun)
  end

  @pad [0, 0, 0, 0, 0, 0, 0 ,0]
  defp number_to_padded_bits(n) do
    digits = Integer.digits(n, 2)
    Enum.take(@pad, 8 - length digits) ++ digits
  end

  @doc """
  Take a piece set and an index. The given index will get added to the piece
  set and the updated piece set will get returned:

      iex> set = Bitfield.new(<<0b10101000>>)
      iex> Bitfield.set(set, 6) |> Bitfield.pieces
      [0, 2, 4, 6]

  """
  def set(%__MODULE__{pieces: pieces, size: size} = state, piece)
  when is_number(piece) and piece < size do
    %__MODULE__{state|pieces: MapSet.put(pieces, piece)}
  end

  @doc """
  Take a piece set and an index. The given index will get removed from the piece
  set and the updated piece set will get returned:

      iex> set = Bitfield.new(<<0b10101000>>)
      iex> Bitfield.remove(set, 2) |> Bitfield.pieces
      [0, 4]

  """
  def remove(%__MODULE__{pieces: pieces, size: size} = state, piece)
  when is_number(piece) and piece < size do
    %__MODULE__{state|pieces: MapSet.delete(pieces, piece)}
  end

  @doc """
  Takes a piece set and a piece number and return `true` if the given piece number
  is present in the set; `false` otherwise.

      iex> set = Bitfield.new(<<0b10000001>>)
      iex> Bitfield.member?(set, 7)
      true
      iex> Bitfield.member?(set, 2)
      false

  """
  def member?(%__MODULE__{pieces: pieces, size: size}, piece_number) when piece_number < size do
    MapSet.member?(pieces, piece_number)
  end

  @doc """
  Takes two piece sets with the same `info_hash`, and return `true` if both sets
  contain exactly the same pieces; and `false` otherwise.

      iex> a = Bitfield.new(<<0b10100110>>)
      iex> b = Bitfield.new(<<0b10100110>>)
      iex> Bitfield.equal?(a, b)
      true
      iex> c = Bitfield.new(<<0b11011011>>)
      iex> Bitfield.equal?(a, c)
      false

  """
  def equal?(%__MODULE__{pieces: a, info_hash: info_hash}, %__MODULE__{pieces: b, info_hash: info_hash}) do
    MapSet.equal?(a, b)
  end

  @doc """
  Takes two piece sets, a and b, who has the same `info_hash`, and return `true` if
  all the members of set a are also members of set b; `false` otherwise.

      iex> a = Bitfield.new(<<0b00000110>>)
      iex> b = Bitfield.new(<<0b00101110>>)
      iex> Bitfield.subset?(a, b)
      true
      iex> Bitfield.subset?(b, a)
      false

  """
  def subset?(%__MODULE__{pieces: a, info_hash: info_hash}, %__MODULE__{pieces: b, info_hash: info_hash}) do
    MapSet.subset?(a, b)
  end

  @doc """
  Takes two piece sets and return `true` if the two sets does not share any members,
  otherwise `false` will get returned.

      iex> a = Bitfield.new(<<0b00101110>>)
      iex> b = Bitfield.new(<<0b11010001>>)
      iex> c = Bitfield.new(<<0b11101000>>)
      iex> Bitfield.disjoint?(a, b)
      true
      iex> Bitfield.disjoint?(a, c)
      false

  """
  def disjoint?(%__MODULE__{pieces: a, info_hash: info_hash}, %__MODULE__{pieces: b, info_hash: info_hash}) do
    MapSet.disjoint?(a, b)
  end

  @doc """
  Takes two piece sets with the same `info_hash` and return a set containing the pieces
  that belong to both sets.

      iex> a = Bitfield.new(<<0b00101010>>)
      iex> b = Bitfield.new(<<0b10110011>>)
      iex> Bitfield.intersection(a, b)
      #MapSet<[2, 6]>

  """
  def intersection(%__MODULE__{pieces: a, info_hash: info_hash}, %__MODULE__{pieces: b, info_hash: info_hash}) do
    MapSet.intersection(a, b)
  end

  @doc """
  Takes two piece sets with the same `info_hash` and return a set containing all
  members of both sets.

      iex> a = Bitfield.new(<<0b00101010>>)
      iex> b = Bitfield.new(<<0b10000000>>)
      iex> Bitfield.union(a, b)
      #MapSet<[0, 2, 4, 6]>

  """
  def union(%__MODULE__{pieces: a, info_hash: info_hash}, %__MODULE__{pieces: b, info_hash: info_hash}) do
    MapSet.union(a, b)
  end

  @doc """
  Takes two piece sets, a and b, who both has the same `info_hash`, and return a MapSet
  containing the pieces in *a* without the pieces contained in *b*.

      iex> a = Bitfield.new(<<170>>)
      iex> b = Bitfield.new(<<85>>)
      iex> Bitfield.difference(a, b)
      #MapSet<[0, 2, 4, 6]>
      iex> Bitfield.difference(b, a)
      #MapSet<[1, 3, 5, 7]>

  """
  def difference(%__MODULE__{info_hash: info_hash, pieces: a}, %__MODULE__{info_hash: info_hash, pieces: b}) do
    MapSet.difference(a, b)
  end

  @doc """
  Take a piece set and return the number of its available pieces.

      iex> Bitfield.new(<<0b10101010>>) |> Bitfield.has
      4

  """
  def has(%__MODULE__{pieces: pieces}) do
    MapSet.size(pieces)
  end

  @doc """
  Take a piece set and return `true` if the set contains all the pieces,
  and `false` otherwise.

      iex> Bitfield.new(<<0b10011010>>) |> Bitfield.has_all?
      false
      iex> Bitfield.new(<<0b11111111>>) |> Bitfield.has_all?
      true

  """
  def has_all?(%__MODULE__{pieces: pieces, size: size}) do
    MapSet.size(pieces) == size
  end

  @doc """
  Take a piece set and return the available pieces in a list.

      iex> Bitfield.new(<<0b10011010>>) |> Bitfield.pieces
      [0, 3, 4, 6]

  """
  def pieces(%__MODULE__{pieces: pieces}) do
    MapSet.to_list(pieces)
  end

  @doc """
  Take a piece set and return the bit field representation of the set.

      iex> Bitfield.new(<<0b10011010, 0b10000000>>) |> Bitfield.to_binary
      <<154, 128>>

  """
  def to_binary(%__MODULE__{size: size, pieces: pieces}) when size > 0 do
    have = MapSet.to_list(pieces)
    bit_range = 0..(size - 1)

    Stream.transform(bit_range, have, fn
      # is the same
      i, [i|rest] ->
        {[1], rest}
      # is not the same
      _, rest ->
        {[0], rest}
    end)
    |> Stream.chunk(8)
    |> Enum.map(&(Integer.undigits(&1, 2)))
    |> IO.iodata_to_binary
  end
end
