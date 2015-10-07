defmodule Bencode.Decoder do
  @spec decode(String.t) ::
    Integer | String.t | List | Map | no_return
  def decode(data) do
    {result, ""} = do_decode(data)
    result
  end

  defp do_decode(<<"i", data::binary>>),
    do: decode_integer(data)
  defp do_decode(<<"l", data::binary>>),
    do: decode_list(data)
  defp do_decode(<<"d", data::binary>>),
    do: decode_dictionary(data)
  defp do_decode(<<first, _::binary>> = data) when first in ?0..?9,
    do: decode_string(data)

  # integer
  defp decode_integer(data, acc \\ [])
  defp decode_integer(<<"e", rest::binary>>, acc),
    do: {prepare_integer(acc), rest}
  defp decode_integer(<<current, data::binary>>, acc) when current == ?- or current in ?0..?9,
    do: decode_integer(data, [current|acc])

  # string
  defp decode_string(data, acc \\ [])
  defp decode_string(<<":", data::binary>>, acc) do
    length = prepare_integer acc
    <<string::size(length)-binary, rest::binary>> = data
    {string, rest}
  end
  defp decode_string(<<current, data::binary>>, acc) when current in ?0..?9,
    do: decode_string(data, [current|acc])

  # list
  defp decode_list(data, acc \\ [])
  defp decode_list(<<"e", data::binary>>, acc),
    do: {acc |> Enum.reverse, data}
  defp decode_list(data, acc) do
    {item, rest} = do_decode(data)
    decode_list(rest, [item|acc])
  end

  # dictionaries
  defp decode_dictionary(data, acc \\ %{})
  defp decode_dictionary(<<"e", data::binary>>, acc),
    do: {acc, data}
  defp decode_dictionary(data, acc) do
    {key, rest} = do_decode(data)
    {value, rest} = do_decode(rest)
    decode_dictionary(rest, Map.put_new(acc, key, value))
  end

  # helpers
  defp prepare_integer(list) do
    list
    |> Enum.reverse
    |> List.to_integer
  end
end
