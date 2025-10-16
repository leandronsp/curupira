defmodule Curupira.Markdown.Parser do
  def to_html(markdown) when is_binary(markdown) do
    case MDEx.to_html(markdown) do
      {:ok, html} -> {:ok, html}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_html(_), do: {:error, :invalid_input}
end
