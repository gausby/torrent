defmodule Tracker.Utils do
  @doc """
  Find the scrape path given an announce path

      iex> Tracker.Utils.to_scrape_path("/announce")
      {:ok, "/scrape"}

      iex> Tracker.Utils.to_scrape_path("/x/y/z/announce.jsp")
      {:ok, "/x/y/z/scrape.jsp"}

  It will return an error tuple if given an invalid announce path.

      iex> Tracker.Utils.to_scrape_path("invalid")
      {:error, "scrape not supported"}
  """
  @spec to_scrape_path(String.t) :: {:ok, String.t} | {:error, String.t}
  def to_scrape_path(announce) do
    [name|path] =
      announce |> String.split("/") |> Enum.reverse

    if String.starts_with? name, "announce" do
      scrape = String.replace(name, "announce", "scrape", global: false)
      {:ok, [scrape|path] |> Enum.reverse |> Enum.join("/")}
    else
      {:error, "scrape not supported"}
    end
  end
end
