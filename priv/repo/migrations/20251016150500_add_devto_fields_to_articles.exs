defmodule Curupira.Repo.Migrations.AddDevtoFieldsToArticles do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :slug, :string
      add :description, :text
      add :canonical_url, :string
      add :cover_image, :string
      add :reading_time_minutes, :integer
      add :comments_count, :integer, default: 0
      add :public_reactions_count, :integer, default: 0
    end

    create index(:articles, [:slug])
  end
end
