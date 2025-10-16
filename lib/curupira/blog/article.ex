defmodule Curupira.Blog.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :title, :string
    field :content, :string
    field :html_preview, :string
    field :status, :string
    field :slug, :string
    field :description, :string
    field :canonical_url, :string
    field :cover_image, :string
    field :reading_time_minutes, :integer
    field :comments_count, :integer
    field :public_reactions_count, :integer
    field :dev_to_id, :integer
    field :dev_to_url, :string
    field :published_at, :utc_datetime
    field :tags, {:array, :string}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [
      :title,
      :content,
      :html_preview,
      :status,
      :slug,
      :description,
      :canonical_url,
      :cover_image,
      :reading_time_minutes,
      :comments_count,
      :public_reactions_count,
      :dev_to_id,
      :dev_to_url,
      :published_at,
      :tags
    ])
    |> validate_required([:title, :content])
    |> unique_constraint(:slug)
  end
end
