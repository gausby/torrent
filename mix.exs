defmodule Torrent.Mixfile do
  use Mix.Project

  def project do
    [app: :torrent,
     version: "0.0.1",
     elixir: "~> 1.1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  def application do
    [applications: [:logger, :cowboy, :plug]]
  end

  # Dependencies
  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"}]
  end
end
