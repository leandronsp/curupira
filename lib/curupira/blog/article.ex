defmodule Curupira.Blog.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :title, :string
    field :content, :string
    field :html_preview, :string
    field :status, :string
    field :dev_to_id, :integer
    field :dev_to_url, :string
    field :published_at, :utc_datetime
    field :tags, {:array, :string}

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :content, :html_preview, :status, :dev_to_id, :dev_to_url, :published_at, :tags])
    |> validate_required([:title, :content])
  end
end
