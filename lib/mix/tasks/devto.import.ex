defmodule Mix.Tasks.Devto.Import do
  @moduledoc """
  Import articles from dev.to

  ## Usage

      mix devto.import [OPTIONS]

  ## Options

      --username  dev.to username (defaults to DEVTO_USERNAME env var)
      --per-page  number of articles per page (default: 30, max: 1000)
      --page      page number to fetch (default: 1)
      --all       fetch ALL articles (ignores --page option)

  ## Examples

      # Import using DEVTO_USERNAME env var
      mix devto.import

      # Import with specific username
      mix devto.import --username leandronsp

      # Import first 100 articles
      mix devto.import --per-page 100

      # Import page 2
      mix devto.import --page 2

      # Import ALL articles (recommended for full sync)
      mix devto.import --all

  """

  use Mix.Task

  alias Curupira.Blog.DevToImporter

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [username: :string, per_page: :integer, page: :integer, all: :boolean]
      )

    Mix.shell().info("Starting dev.to import...")

    result =
      if opts[:all] do
        import_all_with_progress(opts)
      else
        DevToImporter.import_articles(opts)
      end

    case result do
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

  defp import_all_with_progress(opts) do
    progress_callback = fn
      {:fetching, page, count} ->
        Owl.IO.puts([
          Owl.Data.tag("📥 ", :cyan),
          "Fetching page ",
          Owl.Data.tag("#{page}", :yellow),
          " (#{count} articles)"
        ])

      {:fetching_complete, total} ->
        Owl.IO.puts([
          Owl.Data.tag("✓ ", :green),
          "Fetched ",
          Owl.Data.tag("#{total}", :green),
          " articles total\n"
        ])

      {:importing, 0, total} ->
        # Start importing progress bar
        Owl.ProgressBar.start(
          id: :importing,
          label: "Importing articles",
          total: total,
          timer: true,
          bar_width_ratio: 0.5
        )

      {:importing, _current, _total} ->
        Owl.ProgressBar.inc(id: :importing)
    end

    result = DevToImporter.import_all_articles(opts ++ [progress_callback: progress_callback])

    Owl.LiveScreen.await_render()

    result
  end
end
