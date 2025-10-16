defmodule Curupira.Repo.Migrations.CreateArticles do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add :title, :string
      add :content, :text
      add :html_preview, :text
      add :status, :string
      add :dev_to_id, :integer
      add :dev_to_url, :string
      add :published_at, :utc_datetime
      add :tags, {:array, :string}

      timestamps(type: :utc_datetime)
    end
  end
end
