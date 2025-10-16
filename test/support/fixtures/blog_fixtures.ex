defmodule Curupira.BlogFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Curupira.Blog` context.
  """

  @doc """
  Generate a article.
  """
  def article_fixture(attrs \\ %{}) do
    {:ok, article} =
      attrs
      |> Enum.into(%{
        content: "some content",
        title: "some title"
      })
      |> Curupira.Blog.create_article()

    article
  end
end
