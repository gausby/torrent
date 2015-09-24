defmodule Bencode do
  defdelegate encode(data), to: Bencode.Encoder
  defdelegate decode(data), to: Bencode.Decoder
end
