defmodule BitfieldTest do
  use ExUnit.Case
  doctest Bitfield

  test "creating a new bitfield" do
    bitfield = Bitfield.new(32)
    expected = MapSet.new
    assert %Bitfield{size: 32, pieces: ^expected} = bitfield
  end

  test "creating a new bitfield with data" do
    bitfield = Bitfield.new(32, <<128, 64, 32, 48>>)

    expected = MapSet.new([0, 9, 18, 26, 27])
    assert %Bitfield{size: 32, pieces: ^expected} = bitfield
  end

  test "turning a bitfield into a binary" do
    result =
      Bitfield.new(24, <<74, 0, 0>>)
      |> Bitfield.to_binary
    expected = <<74, 0, 0>>
    assert result == expected

    result =
      Bitfield.new(24, <<0, 74, 0>>)
      |> Bitfield.to_binary
    expected = <<0, 74, 0>>
    assert result == expected

    result =
      Bitfield.new(24, <<0, 0, 74>>)
      |> Bitfield.to_binary
    expected = <<0, 0, 74>>
    assert result == expected

    result =
      Bitfield.new(24, <<1, 255, 74>>)
      |> Bitfield.to_binary
    expected = <<1, 255, 74>>
    assert result == expected
  end

  test "getting bits" do
    bitfield = Bitfield.new(32, <<128, 129, 255, 1>>)

    assert Bitfield.member?(bitfield, 0) == true
    assert Bitfield.member?(bitfield, 1) == false
    assert Bitfield.member?(bitfield, 8) == true
    assert Bitfield.member?(bitfield, 14) == false
    assert Bitfield.member?(bitfield, 15) == true
    assert Bitfield.member?(bitfield, 16) == true

    assert Bitfield.member?(bitfield, 30) == false
    assert Bitfield.member?(bitfield, 31) == true
  end

  test "setting bits" do
    result =
      Bitfield.new(16)
      |> Bitfield.set(2)
      |> Bitfield.set(4)
      |> Bitfield.set(6)
      |> Bitfield.set(8)
      |> Bitfield.set(15)

    expected = <<42, 129>>
    assert Bitfield.to_binary(result) == expected
  end

  test "removing bits" do
    bitfield =
      Bitfield.new(8)
      |> Bitfield.set(2)
      |> Bitfield.remove(2)
    assert Bitfield.to_binary(bitfield) == <<0>>

    bitfield =
      Bitfield.new(8)
      |> Bitfield.set(0)
      |> Bitfield.set(2)
      |> Bitfield.set(4)
      |> Bitfield.set(6) # 10101010
      |> Bitfield.remove(0) # 101010
    assert Bitfield.to_binary(bitfield) == <<42>>
  end

  test "counting the available pieces in a bitfield" do
    assert Bitfield.has(Bitfield.new(8, <<255>>)) == 8
    assert Bitfield.has(Bitfield.new(8, <<170>>)) == 4
    assert Bitfield.has(Bitfield.new(8, <<42>>)) == 3
    assert Bitfield.has(Bitfield.new(8, <<10>>)) == 2
    assert Bitfield.has(Bitfield.new(8, <<1>>)) == 1
    assert Bitfield.has(Bitfield.new(8, <<0>>)) == 0

    assert Bitfield.has(Bitfield.new(24, <<1,1,1>>)) == 3
    assert Bitfield.has(Bitfield.new(24, <<10,10,10>>)) == 6
    assert Bitfield.has(Bitfield.new(24, <<170,170,170>>)) == 12
  end

  test "has all" do
    assert Bitfield.has_all?(Bitfield.new(8, <<255>>)) == true
    assert Bitfield.has_all?(Bitfield.new(8, <<254>>)) == false
    assert Bitfield.has_all?(Bitfield.new(16, <<255, 1>>)) == false
    assert Bitfield.has_all?(Bitfield.new(16, <<255, 255>>)) == true
  end

  test "intersection" do
    bitfield1 = Bitfield.new(16, <<190, 106>>)
    bitfield2 = Bitfield.new(16, <<106, 190>>)

    expected = MapSet.new([2, 4, 6, 10, 12, 14])
    assert expected == Bitfield.intersection(bitfield1, bitfield2)
  end

  test "disjoint" do
    bitfield1 = Bitfield.new(16, <<0, 255>>)
    bitfield2 = Bitfield.new(16, <<255, 0>>)
    bitfield3 = Bitfield.new(16, <<128, 128>>)

    assert Bitfield.disjoint?(bitfield1, bitfield2) == true
    assert Bitfield.disjoint?(bitfield1, bitfield3) == false
  end

  test "equal" do
    bitfield1 = Bitfield.new(16, <<0, 255>>)
    bitfield2 = Bitfield.new(16, <<255, 0>>)
    bitfield3 = Bitfield.new(16, <<0, 255>>)

    assert Bitfield.equal?(bitfield1, bitfield2) == false
    assert Bitfield.equal?(bitfield1, bitfield3) == true
  end
end
