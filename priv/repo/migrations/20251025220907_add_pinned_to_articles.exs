defmodule Curupira.Repo.Migrations.AddPinnedToArticles do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :pinned, :boolean, default: false, null: false
    end

    create index(:articles, [:pinned])
  end
end
