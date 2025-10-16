defmodule Curupira.Markdown.ParserTest do
  use ExUnit.Case, async: true

  alias Curupira.Markdown.Parser

  describe "to_html/1" do
    test "converts markdown to HTML" do
      markdown = "# Hello World"
      assert {:ok, html} = Parser.to_html(markdown)
      assert html =~ "<h1>Hello World</h1>"
    end

    test "handles bold text" do
      markdown = "**bold text**"
      assert {:ok, html} = Parser.to_html(markdown)
      assert html =~ "<strong>bold text</strong>"
    end

    test "handles italic text" do
      markdown = "_italic text_"
      assert {:ok, html} = Parser.to_html(markdown)
      assert html =~ "<em>italic text</em>"
    end

    test "handles code blocks" do
      markdown = "```elixir\ndefmodule Test do\nend\n```"
      assert {:ok, html} = Parser.to_html(markdown)
      assert html =~ "<code"
    end

    test "handles links" do
      markdown = "[Link](https://example.com)"
      assert {:ok, html} = Parser.to_html(markdown)
      assert html =~ "<a href=\"https://example.com\">Link</a>"
    end

    test "returns error for invalid input" do
      assert {:error, :invalid_input} = Parser.to_html(nil)
      assert {:error, :invalid_input} = Parser.to_html(123)
    end
  end
end
