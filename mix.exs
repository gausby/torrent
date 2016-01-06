defmodule Torrent.Mixfile do
  use Mix.Project

  def project do
    [app: :torrent,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :gproc],
     mod: {Torrent, []}]
  end

  defp deps do
    [{:bencode, "~> 0.2.0"},
     {:bit_field_set, "~> 0.0.1"},
     {:gproc, "~> 0.5.0"}]
  end
end
