defmodule Curupira.Blog.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "blog_profile" do
    field :name, :string
    field :bio, :string
    field :avatar_url, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :bio, :avatar_url])
    |> validate_required([:name])
  end
end
