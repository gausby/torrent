defprotocol Bencode.Encoder do
  @doc """
  Encode strings, itegers, lists and dicts into their bencode representation:

    iex> Bencode.Encoder.encode("foo")
    "3:foo"

    iex> Bencode.Encoder.encode(42)
    "i42e"

    iex> Bencode.Encoder.encode(["spam", 42])
    "l4:spami42ee"

    iex> Bencode.Encoder.encode(%{"bar" => "spam", "foo" => 42})
    "d3:bar4:spam3:fooi42ee"
  """
  def encode(data)
end

defimpl Bencode.Encoder, for: BitString do
  def encode(data),
    do: "#{String.length data}:#{data}"
end

defimpl Bencode.Encoder, for: Integer do
  def encode(data),
    do: "i#{data}e"
end

defimpl Bencode.Encoder, for: List do
  def encode(data),
    do: "l#{Enum.map_join(data, &Bencode.Encoder.encode/1)}e"
end

defimpl Bencode.Encoder, for: Map do
  def encode(data),
    do: "d#{Enum.map_join(data, &encode_pair/1)}e"

  defp encode_pair({key, value}),
    do: "#{Bencode.Encoder.encode key}#{Bencode.Encoder.encode value}"
end
