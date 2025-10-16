defmodule CurupiraWeb.ArticleLive.Index do
  use CurupiraWeb, :live_view

  alias Curupira.Blog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search_query = params["q"] || ""

    opts = [page: page, per_page: 10]
    opts = if search_query != "", do: Keyword.put(opts, :search, search_query), else: opts

    pagination = Blog.list_articles_paginated(opts)

    {:noreply,
     socket
     |> apply_action(socket.assigns.live_action, params)
     |> assign(:search_query, search_query)
     |> assign(:pagination, pagination)
     |> stream(:articles, pagination.articles, reset: true)}
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

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    search_query = String.trim(query)

    params = if search_query == "", do: %{}, else: %{"q" => search_query}

    {:noreply, push_patch(socket, to: ~p"/articles?#{params}")}
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      # If 7 or fewer pages, show all
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      # If current page is near the start
      current_page <= 4 ->
        [1, 2, 3, 4, 5, :gap, total_pages]

      # If current page is near the end
      current_page >= total_pages - 3 ->
        [1, :gap] ++ Enum.to_list((total_pages - 4)..total_pages)

      # Current page is in the middle
      true ->
        [1, :gap, current_page - 1, current_page, current_page + 1, :gap, total_pages]
    end
  end
end
