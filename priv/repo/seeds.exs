# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Curupira.Repo.insert!(%Curupira.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Curupira.Repo
alias Curupira.Blog.Article

Repo.insert!(%Article{
  title: "Getting Started with Phoenix LiveView",
  content: """
  # Getting Started with Phoenix LiveView

  Phoenix LiveView is a powerful library that enables **rich, real-time user experiences** with server-rendered HTML.

  ## Why LiveView?

  - Write interactive apps without JavaScript
  - Real-time updates via WebSockets
  - Server-side rendering for SEO
  - Simple mental model

  ## Example Code

  ```elixir
  defmodule MyAppWeb.CounterLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket) do
      {:ok, assign(socket, count: 0)}
    end

    def handle_event("increment", _, socket) do
      {:noreply, assign(socket, count: socket.assigns.count + 1)}
    end
  end
  ```

  Check out the [official docs](https://hexdocs.pm/phoenix_live_view) for more info.
  """
})

Repo.insert!(%Article{
  title: "Markdown Basics",
  content: """
  # Markdown Basics

  Learn the essentials of **Markdown** syntax.

  ## Headers

  Use `#` for headers. More `#` symbols = smaller headers.

  ## Emphasis

  - *Italic* with `*asterisks*` or `_underscores_`
  - **Bold** with `**double asterisks**`
  - ~~Strikethrough~~ with `~~tildes~~`

  ## Lists

  Unordered lists use `*`, `-`, or `+`:

  * Item 1
  * Item 2
    * Nested item

  Ordered lists use numbers:

  1. First item
  2. Second item
  3. Third item

  ## Links and Images

  [Link text](https://example.com)

  ![Alt text](https://via.placeholder.com/150)

  ## Code

  Inline `code` with backticks.

  Block code with triple backticks:

  ```ruby
  def hello
    puts "Hello, World!"
  end
  ```
  """
})
