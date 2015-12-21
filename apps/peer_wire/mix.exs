defmodule PeerWire.Mixfile do
  use Mix.Project

  def project do
    [app: :peer_wire,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :gproc],
     mod: {PeerWire, [port: 9000]}]
  end

  defp deps do
    [{:gproc, "~> 0.5.0"},
     {:connection, "~> 1.0"},
     {:bencode, "~> 0.2.0"}]
  end
end
