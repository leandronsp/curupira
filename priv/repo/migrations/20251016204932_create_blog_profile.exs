defmodule Curupira.Repo.Migrations.CreateBlogProfile do
  use Ecto.Migration

  def change do
    create table(:blog_profile) do
      add :name, :string
      add :bio, :text
      add :description, :text
      add :avatar_url, :string

      timestamps(type: :utc_datetime)
    end
  end
end
