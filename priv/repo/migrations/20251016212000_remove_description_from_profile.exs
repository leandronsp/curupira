defmodule Curupira.Repo.Migrations.RemoveDescriptionFromProfile do
  use Ecto.Migration

  def change do
    alter table(:blog_profile) do
      remove :description
    end
  end
end
