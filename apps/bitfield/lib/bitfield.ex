defmodule Bitfield do
  defstruct(
    size: 0,
    pieces: MapSet.new
  )

  @pad [0, 0, 0, 0, 0, 0, 0 ,0]
  defp pad(digits) do
    Enum.take(@pad, 8 - length digits) ++ digits
  end

  defp number_to_padded_bits(n) when is_number(n) do
    Integer.digits(n, 2) |> pad
  end

  # ====================================================================
  def new(size) do
    %__MODULE__{size: size}
  end

  def new(size, content) when is_binary(content) do
    pieces = reduce_bits(content, fn
      {index, 1}, acc ->
        [index|acc]
      _, acc ->
        acc
    end)
    %__MODULE__{size: size, pieces: MapSet.new(pieces)}
  end

  @doc """
  Reduce the bits in the bytes in the bit-field
  """
  def reduce_bits(bytes, fun),
    do: do_reduce_bits(bytes, 0, [], fun)

  def do_reduce_bits(<<>>, _index, acc, _fun),
    do: Enum.reverse acc
  def do_reduce_bits(<<byte::integer, rest::binary>>, index, acc, fun) do
    {index, acc} =
      number_to_padded_bits(byte)
      |> Enum.reduce({index, acc}, fn bit, {index, acc} ->
           {index + 1, fun.({index, bit}, acc)}
         end)

    do_reduce_bits(rest, index, acc, fun)
  end

  def set(%__MODULE__{pieces: pieces, size: size} = state, piece)
  when is_number(piece) and piece < size do
    %__MODULE__{state|pieces: MapSet.put(pieces, piece)}
  end

  def member?(%__MODULE__{pieces: pieces, size: size}, piece_number) when piece_number < size do
    MapSet.member?(pieces, piece_number)
  end

  def equal?(%__MODULE__{size: size, pieces: a}, %__MODULE__{size: size, pieces: b}) do
    MapSet.equal?(a, b)
  end

  def disjoint?(%__MODULE__{size: size, pieces: a}, %__MODULE__{size: size, pieces: b}) do
    MapSet.disjoint?(a, b)
  end

  def intersection(%__MODULE__{size: size, pieces: a}, %__MODULE__{size: size, pieces: b}) do
    MapSet.intersection(a, b)
  end

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
