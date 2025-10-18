defmodule Curupira.Repo.Migrations.AddLanguageToArticles do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :language, :string, default: "en"
    end

    # Populate language based on title/content detection
    execute("""
      UPDATE articles
      SET language = CASE
        WHEN title ~ '[àáâãçéêíóôõú]' THEN 'pt-BR'
        WHEN title ~ '(^|\\s)(um|em|de|do|da|para|com)\\s' THEN 'pt-BR'
        ELSE 'en'
      END
    """, "")
  end
end
