defmodule Curupira.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false
  alias Curupira.Repo

  alias Curupira.Blog.Article
  alias Curupira.Blog.Profile

  @doc """
  Returns the list of articles.

  ## Examples

      iex> list_articles()
      [%Article{}, ...]

  """
  def list_articles do
    Repo.all(Article)
  end

  @doc """
  Returns the list of published articles ordered by published_at DESC.

  ## Examples

      iex> list_published_articles()
      [%Article{}, ...]

  """
  def list_published_articles do
    from(a in Article,
      where: a.status == "published",
      order_by: [
        desc: a.pinned,
        desc: a.published_at,
        desc: a.inserted_at
      ]
    )
    |> Repo.all()
  end

  @doc """
  Returns paginated articles ordered by published_at DESC.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 10)
    * `:search` - Search term to filter by title (optional)

  ## Examples

      iex> list_articles_paginated(page: 1, per_page: 10)
      %{articles: [%Article{}, ...], total_count: 100, page: 1, per_page: 10, total_pages: 10}

      iex> list_articles_paginated(page: 1, per_page: 10, search: "elixir")
      %{articles: [%Article{}, ...], total_count: 5, page: 1, per_page: 10, total_pages: 1}

  """
  def list_articles_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    search = Keyword.get(opts, :search)

    offset = (page - 1) * per_page

    base_query = from a in Article

    query =
      base_query
      |> maybe_filter_by_search(search)
      |> order_by([a], [
        desc: a.pinned,
        asc: fragment("CASE WHEN ? = 'published' THEN 1 ELSE 0 END", a.status),
        desc: a.published_at,
        desc: a.inserted_at
      ])
      |> limit(^per_page)
      |> offset(^offset)

    count_query = maybe_filter_by_search(base_query, search)

    articles = Repo.all(query)
    total_count = Repo.aggregate(count_query, :count)
    total_pages = ceil(total_count / per_page)

    %{
      articles: articles,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
  end

  defp maybe_filter_by_search(query, nil), do: query
  defp maybe_filter_by_search(query, ""), do: query
  defp maybe_filter_by_search(query, search) do
    search_pattern = "%#{search}%"
    from a in query, where: ilike(a.title, ^search_pattern)
  end

  @doc """
  Gets a single article.

  Raises `Ecto.NoResultsError` if the Article does not exist.

  ## Examples

      iex> get_article!(123)
      %Article{}

      iex> get_article!(456)
      ** (Ecto.NoResultsError)

  """
  def get_article!(id), do: Repo.get!(Article, id)

  @doc """
  Gets a single article by dev.to ID.

  Returns `nil` if the Article does not exist.

  ## Examples

      iex> get_article_by_dev_to_id(123)
      %Article{}

      iex> get_article_by_dev_to_id(456)
      nil

  """
  def get_article_by_dev_to_id(dev_to_id) do
    Repo.get_by(Article, dev_to_id: dev_to_id)
  end

  @doc """
  Creates a article.

  ## Examples

      iex> create_article(%{field: value})
      {:ok, %Article{}}

      iex> create_article(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_article(attrs) do
    %Article{}
    |> Article.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a article.

  ## Examples

      iex> update_article(article, %{field: new_value})
      {:ok, %Article{}}

      iex> update_article(article, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_article(%Article{} = article, attrs) do
    article
    |> Article.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a article.

  ## Examples

      iex> delete_article(article)
      {:ok, %Article{}}

      iex> delete_article(article)
      {:error, %Ecto.Changeset{}}

  """
  def delete_article(%Article{} = article) do
    Repo.delete(article)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking article changes.

  ## Examples

      iex> change_article(article)
      %Ecto.Changeset{data: %Article{}}

  """
  def change_article(%Article{} = article, attrs \\ %{}) do
    Article.changeset(article, attrs)
  end

  @doc """
  Pins an article. Unpins any other pinned articles first (only one article can be pinned at a time).

  ## Examples

      iex> pin_article(article)
      {:ok, %Article{pinned: true}}

  """
  def pin_article(%Article{} = article) do
    Repo.transaction(fn ->
      # Unpin all articles first
      from(a in Article, where: a.pinned == true)
      |> Repo.update_all(set: [pinned: false])

      # Pin the selected article
      article
      |> Article.changeset(%{pinned: true})
      |> Repo.update!()
    end)
  end

  @doc """
  Unpins an article.

  ## Examples

      iex> unpin_article(article)
      {:ok, %Article{pinned: false}}

  """
  def unpin_article(%Article{} = article) do
    article
    |> Article.changeset(%{pinned: false})
    |> Repo.update()
  end

  @doc """
  Gets the currently pinned article, if any.

  ## Examples

      iex> get_pinned_article()
      %Article{}

      iex> get_pinned_article()
      nil

  """
  def get_pinned_article do
    from(a in Article, where: a.pinned == true)
    |> Repo.one()
  end

  # Blog Profile functions

  @doc """
  Gets or creates the blog profile (singleton).

  ## Examples

      iex> get_or_create_profile()
      %Profile{}

  """
  def get_or_create_profile do
    case Repo.one(Profile) do
      nil ->
        {:ok, profile} = create_profile(%{name: "My Blog"})
        profile

      profile ->
        profile
    end
  end

  @doc """
  Creates a profile.

  ## Examples

      iex> create_profile(%{name: "My Blog"})
      {:ok, %Profile{}}

      iex> create_profile(%{})
      {:error, %Ecto.Changeset{}}

  """
  def create_profile(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates the blog profile.

  ## Examples

      iex> update_profile(profile, %{name: "New Name"})
      {:ok, %Profile{}}

      iex> update_profile(profile, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_profile(%Profile{} = profile, attrs) do
    profile
    |> Profile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking profile changes.

  ## Examples

      iex> change_profile(profile)
      %Ecto.Changeset{data: %Profile{}}

  """
  def change_profile(%Profile{} = profile, attrs \\ %{}) do
    Profile.changeset(profile, attrs)
  end
end
