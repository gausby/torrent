defmodule Tracker.Mixfile do
  use Mix.Project

  def project do
    [app: :tracker,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.1",
     test_pattern: "*_{test,eqc}.exs",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  def application do
    [applications: [:logger, :gproc, :cowboy, :plug]]
  end

  # Dependencies can be Hex packages:
  defp deps do
    [{:eqc_ex, "~> 1.2.4"},
     {:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:gproc, "~> 0.5.0"},
     {:uuid, "~> 1.0.1"},
     {:bencode, "~> 0.1.1"}]
  end
end
