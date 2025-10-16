defmodule CurupiraWeb.ArticleLive.Index do
  use CurupiraWeb, :live_view

  alias Curupira.Blog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :articles, Blog.list_articles())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Articles")
    |> assign(:article, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    article = Blog.get_article!(id)
    {:ok, _} = Blog.delete_article(article)

    {:noreply, stream_delete(socket, :articles, article)}
  end
end
