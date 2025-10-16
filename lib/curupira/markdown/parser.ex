defmodule Curupira.Markdown.Parser do
  def to_html(markdown) when is_binary(markdown) do
    opts = [
      extension: [
        strikethrough: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      parse: [
        smart: true
      ],
      render: [
        hardbreaks: true,
        unsafe: true
      ]
    ]

    case MDEx.to_html(markdown, opts) do
      {:ok, html} -> {:ok, html}
      {:error, reason} -> {:error, reason}
    end
  end

  def to_html(_), do: {:error, :invalid_input}
end
