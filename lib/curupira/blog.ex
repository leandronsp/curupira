defmodule Curupira.Blog do
  @moduledoc """
  The Blog context.
  """

  import Ecto.Query, warn: false
  alias Curupira.Repo

  alias Curupira.Blog.Article

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
  Returns paginated articles ordered by published_at DESC.

  ## Options

    * `:page` - Page number (default: 1)
    * `:per_page` - Items per page (default: 10)

  ## Examples

      iex> list_articles_paginated(page: 1, per_page: 10)
      %{articles: [%Article{}, ...], total_count: 100, page: 1, per_page: 10, total_pages: 10}

  """
  def list_articles_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    offset = (page - 1) * per_page

    query = from a in Article,
            order_by: [desc: a.published_at, desc: a.inserted_at],
            limit: ^per_page,
            offset: ^offset

    articles = Repo.all(query)
    total_count = Repo.aggregate(Article, :count)
    total_pages = ceil(total_count / per_page)

    %{
      articles: articles,
      total_count: total_count,
      page: page,
      per_page: per_page,
      total_pages: total_pages
    }
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
end
