defmodule BencodeEQC do
  use ExUnit.Case
  use EQC.ExUnit

  # ints
  property "Output of encoding ints followed by a decode should result in the input" do
    forall input <- int do
      ensure Bencode.decode(Bencode.encode(input)) == input
    end
  end

  property "Output of encoding lists of ints followed by a decode should result in the input" do
    forall input <- list(int) do
      ensure Bencode.decode(Bencode.encode(input)) == input
    end
  end

  property "Encoding strings followed by a decode should result in the input" do
    forall input <- utf8 do
      ensure Bencode.decode(Bencode.encode(input)) == input
    end
  end

  property "Encoding lists of strings followed by a decode should result in the input" do
    forall input <- list(utf8) do
      ensure Bencode.decode(Bencode.encode(input)) == input
    end
  end
end
