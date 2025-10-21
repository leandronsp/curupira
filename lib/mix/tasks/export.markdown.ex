defmodule Mix.Tasks.Export.Markdown do
  @moduledoc """
  Export articles as markdown files to ../leandronsp.com

  ## Usage

      mix export.markdown [OPTIONS]

  ## Options

      --output  output directory (default: ../leandronsp.com/articles)
      --all     export all articles (default: only published)

  ## Examples

      # Export published articles to default location
      mix export.markdown

      # Export all articles including drafts
      mix export.markdown --all

      # Export to custom directory
      mix export.markdown --output /path/to/output

  """

  use Mix.Task

  import Ecto.Query

  alias Curupira.Blog
  alias Curupira.Repo

  @requirements ["app.start"]

  @impl Mix.Task
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [output: :string, all: :boolean]
      )

    output_dir = Keyword.get(opts, :output, "../leandronsp.com/articles")
    export_all = Keyword.get(opts, :all, false)

    Mix.shell().info("Exporting articles to #{output_dir}...")

    # Create output directory
    File.mkdir_p!(output_dir)

    # Get articles
    articles =
      if export_all do
        Blog.list_articles()
      else
        Repo.all(
          from a in Curupira.Blog.Article,
            where: a.status == "published",
            order_by: [desc: a.published_at]
        )
      end

    # Export each article
    Enum.each(articles, fn article ->
      export_article(article, output_dir)
    end)

    Mix.shell().info("✓ Exported #{length(articles)} articles")
  end

  defp export_article(article, output_dir) do
    # Create filename from slug
    filename = "#{article.slug}.md"
    filepath = Path.join(output_dir, filename)

    # Build frontmatter
    frontmatter = build_frontmatter(article)

    # Combine frontmatter and content
    markdown_content = """
    ---
    #{frontmatter}
    ---

    #{article.content}
    """

    # Write file
    File.write!(filepath, markdown_content)

    Mix.shell().info("  → #{filename}")
  end

  defp build_frontmatter(article) do
    """
    title: "#{escape_yaml(article.title)}"
    slug: "#{article.slug}"
    published_at: "#{article.published_at || article.inserted_at}"
    language: "#{article.language || "en"}"
    status: "#{article.status || "draft"}"
    tags: [#{format_tags(article.tags)}]
    """
    |> String.trim()
  end

  defp escape_yaml(nil), do: ""
  defp escape_yaml(text), do: String.replace(text, "\"", "\\\"")

  defp format_tags(nil), do: ""
  defp format_tags([]), do: ""

  defp format_tags(tags) do
    tags
    |> Enum.map(&"\"#{&1}\"")
    |> Enum.join(", ")
  end
end
