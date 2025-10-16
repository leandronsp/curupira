defmodule Curupira.Blog.DevToImporter do
  @moduledoc """
  Imports articles from dev.to API into the local database.
  """

  require Logger

  alias Curupira.Blog
  alias Curupira.Markdown.Parser

  @dev_to_api_url "https://dev.to/api/articles"

  @doc """
  Imports articles from dev.to for the given username.

  ## Options

    * `:username` - The dev.to username to import from (defaults to DEVTO_USERNAME env var)
    * `:per_page` - Number of articles per page (default: 30, max: 1000)
    * `:page` - Page number to fetch (default: 1)

  ## Examples

      iex> DevToImporter.import_articles(username: "leandronsp")
      {:ok, [%Article{}, ...]}

      iex> DevToImporter.import_articles()
      {:ok, [%Article{}, ...]}  # Uses DEVTO_USERNAME env var

  """
  def import_articles(opts \\ []) do
    username = opts[:username] || get_username_from_env()
    per_page = opts[:per_page] || 30
    page = opts[:page] || 1

    Logger.info("Importing articles from dev.to for user: #{username}")

    with {:ok, articles} <- fetch_articles(username, per_page, page),
         {:ok, imported} <- import_into_database(articles) do
      Logger.info("Successfully imported #{length(imported)} articles")
      {:ok, imported}
    end
  end

  @doc """
  Imports ALL articles from dev.to for the given username.
  Fetches all pages until no more articles are returned.

  ## Options

    * `:username` - The dev.to username to import from (defaults to DEVTO_USERNAME env var)
    * `:per_page` - Number of articles per page (default: 1000, max: 1000)
    * `:progress_callback` - Function called with progress updates (fn page, total -> :ok end)

  ## Examples

      iex> DevToImporter.import_all_articles(username: "leandronsp")
      {:ok, [%Article{}, ...]}

      iex> DevToImporter.import_all_articles()
      {:ok, [%Article{}, ...]}  # Uses DEVTO_USERNAME env var

  """
  def import_all_articles(opts \\ []) do
    username = opts[:username] || get_username_from_env()
    per_page = opts[:per_page] || 1000
    progress_callback = opts[:progress_callback]

    Logger.info("Importing ALL articles from dev.to for user: #{username}")

    fetch_all_pages(username, per_page, 1, [], progress_callback)
  end

  defp fetch_all_pages(username, per_page, page, accumulated, progress_callback) do
    case fetch_articles(username, per_page, page) do
      {:ok, []} ->
        # No more articles, import everything we collected
        Logger.info("Fetched all pages. Total articles: #{length(accumulated)}")

        if progress_callback do
          progress_callback.({:fetching_complete, length(accumulated)})
        end

        import_into_database_with_progress(accumulated, progress_callback)

      {:ok, articles} ->
        Logger.info("Page #{page}: fetched #{length(articles)} articles")

        if progress_callback do
          progress_callback.({:fetching, page, length(articles)})
        end

        # Continue to next page
        fetch_all_pages(username, per_page, page + 1, accumulated ++ articles, progress_callback)

      {:error, reason} ->
        Logger.error("Failed to fetch page #{page}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp import_into_database_with_progress(articles, nil) do
    import_into_database(articles)
  end

  defp import_into_database_with_progress(articles, progress_callback) do
    # Filter out boost articles
    filtered_articles = Enum.reject(articles, &is_boost_article?/1)

    Logger.info("Filtered #{length(articles) - length(filtered_articles)} boost articles")

    total = length(filtered_articles)

    if progress_callback do
      progress_callback.({:importing, 0, total})
    end

    results =
      filtered_articles
      |> Enum.with_index(1)
      |> Enum.map(fn {article_data, index} ->
        result = case import_single_article(article_data) do
          {:ok, article} ->
            Logger.debug("Imported article: #{article.title}")
            {:ok, article}

          {:error, changeset} ->
            Logger.error("Failed to import article: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

        if progress_callback do
          progress_callback.({:importing, index, total})
        end

        result
      end)

    successful = Enum.filter(results, fn {status, _} -> status == :ok end)
    failed = Enum.filter(results, fn {status, _} -> status == :error end)

    if length(failed) > 0 do
      Logger.warning("#{length(failed)} articles failed to import")
    end

    {:ok, Enum.map(successful, fn {:ok, article} -> article end)}
  end

  @doc """
  Fetches articles from dev.to API.
  """
  def fetch_articles(username, per_page \\ 30, page \\ 1) do
    url = "#{@dev_to_api_url}?username=#{username}&per_page=#{per_page}&page=#{page}"

    case Req.get(url) do
      {:ok, %{status: 200, body: articles}} ->
        Logger.info("Fetched #{length(articles)} articles from dev.to")
        {:ok, articles}

      {:ok, %{status: status}} ->
        Logger.error("Failed to fetch articles from dev.to: HTTP #{status}")
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        Logger.error("Failed to fetch articles from dev.to: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Fetches a single article with full content from dev.to API.
  """
  def fetch_single_article(article_id) do
    url = "#{@dev_to_api_url}/#{article_id}"

    case Req.get(url) do
      {:ok, %{status: 200, body: article}} ->
        Logger.debug("Fetched article #{article_id} from dev.to")
        {:ok, article}

      {:ok, %{status: status}} ->
        Logger.error("Failed to fetch article #{article_id} from dev.to: HTTP #{status}")
        {:error, "HTTP request failed with status #{status}"}

      {:error, error} ->
        Logger.error("Failed to fetch article #{article_id} from dev.to: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Imports a list of dev.to articles into the database.
  Creates new articles or updates existing ones based on dev_to_id.
  Filters out boost articles (title "[Boost]" or contains embed tags).
  """
  def import_into_database(articles) when is_list(articles) do
    # Filter out boost articles
    filtered_articles = Enum.reject(articles, &is_boost_article?/1)

    Logger.info("Filtered #{length(articles) - length(filtered_articles)} boost articles")

    results =
      Enum.map(filtered_articles, fn article_data ->
        case import_single_article(article_data) do
          {:ok, article} ->
            Logger.debug("Imported article: #{article.title}")
            {:ok, article}

          {:error, changeset} ->
            Logger.error("Failed to import article: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
      end)

    successful = Enum.filter(results, fn {status, _} -> status == :ok end)
    failed = Enum.filter(results, fn {status, _} -> status == :error end)

    if length(failed) > 0 do
      Logger.warning("#{length(failed)} articles failed to import")
    end

    {:ok, Enum.map(successful, fn {:ok, article} -> article end)}
  end

  defp import_single_article(data) do
    dev_to_id = data["id"]

    # Fetch full article content from individual article endpoint
    article_data =
      case fetch_single_article(dev_to_id) do
        {:ok, full_data} -> full_data
        {:error, _} -> data
      end

    attrs = %{
      dev_to_id: dev_to_id,
      title: article_data["title"],
      description: article_data["description"],
      content: article_data["body_markdown"] || "",
      slug: article_data["slug"],
      canonical_url: article_data["canonical_url"],
      cover_image: article_data["cover_image"],
      published_at: parse_datetime(article_data["published_at"]),
      reading_time_minutes: article_data["reading_time_minutes"],
      comments_count: article_data["comments_count"] || 0,
      public_reactions_count: article_data["public_reactions_count"] || 0,
      dev_to_url: article_data["url"],
      tags: parse_tags(article_data["tag_list"]),
      status: "published"
    }

    # Generate HTML preview
    attrs =
      case generate_html_preview(attrs.title, attrs.content) do
        {:ok, html} -> Map.put(attrs, :html_preview, html)
        {:error, _} -> attrs
      end

    # Check if article already exists by dev_to_id
    case Blog.get_article_by_dev_to_id(dev_to_id) do
      nil ->
        Blog.create_article(attrs)

      existing_article ->
        Blog.update_article(existing_article, attrs)
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  defp parse_tags(nil), do: []
  defp parse_tags([]), do: []

  defp parse_tags(tags) when is_list(tags), do: tags

  defp parse_tags(tags_string) when is_binary(tags_string) do
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_tags(_), do: []

  defp generate_html_preview(title, content) do
    full_markdown = build_full_markdown(title, content)
    Parser.to_html(full_markdown)
  end

  defp build_full_markdown(nil, nil), do: ""
  defp build_full_markdown(nil, content) when is_binary(content), do: content
  defp build_full_markdown("", content) when is_binary(content), do: content
  defp build_full_markdown(title, nil) when is_binary(title), do: "# #{title}"
  defp build_full_markdown(title, "") when is_binary(title), do: "# #{title}"

  defp build_full_markdown(title, content) when is_binary(title) and is_binary(content) do
    "# #{title}\n\n#{content}"
  end

  defp build_full_markdown(_, _), do: ""

  defp get_username_from_env do
    case System.get_env("DEVTO_USERNAME") do
      nil ->
        raise """
        DEVTO_USERNAME environment variable not set.
        Please set it to your dev.to username or pass the :username option.
        """

      username ->
        username
    end
  end

  defp is_boost_article?(article) do
    title = article["title"] || ""
    body = article["body_markdown"] || ""

    title == "[Boost]" || String.contains?(body, "{% embed")
  end
end
