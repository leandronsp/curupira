defmodule Mix.Tasks.Devto.Import do
  @moduledoc """
  Import articles from dev.to

  ## Usage

      mix devto.import [OPTIONS]

  ## Options

      --username  dev.to username (defaults to DEVTO_USERNAME env var)
      --per-page  number of articles per page (default: 30, max: 1000)
      --page      page number to fetch (default: 1)

  ## Examples

      # Import using DEVTO_USERNAME env var
      mix devto.import

      # Import with specific username
      mix devto.import --username leandronsp

      # Import first 100 articles
      mix devto.import --per-page 100

      # Import page 2
      mix devto.import --page 2

  """

  use Mix.Task

  alias Curupira.Blog.DevToImporter

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [username: :string, per_page: :integer, page: :integer]
      )

    Mix.shell().info("Starting dev.to import...")

    case DevToImporter.import_articles(opts) do
      {:ok, articles} ->
        Mix.shell().info("✓ Successfully imported #{length(articles)} articles")

        if length(articles) > 0 do
          Mix.shell().info("\nImported articles:")

          Enum.each(articles, fn article ->
            Mix.shell().info("  • #{article.title}")
          end)
        end

      {:error, reason} ->
        Mix.shell().error("✗ Import failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
