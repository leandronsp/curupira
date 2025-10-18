defmodule CurupiraWeb.ArticleLive.Index do
  use CurupiraWeb, :live_view

  alias Curupira.Blog

  @impl true
  def mount(_params, _session, socket) do
    profile = Blog.get_or_create_profile()

    {:ok,
     socket
     |> assign(:profile, profile)
     |> assign(:profile_form, Blog.change_profile(profile))}
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

  @impl true
  def handle_event("update_profile", %{"field" => field, "value" => value}, socket) do
    profile = socket.assigns.profile

    # Convert field string to atom
    field_atom = String.to_existing_atom(field)
    attrs = %{field_atom => value}

    case Blog.update_profile(profile, attrs) do
      {:ok, updated_profile} ->
        {:noreply, assign(socket, :profile, updated_profile)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_publish", %{"id" => id}, socket) do
    article = Blog.get_article!(id)
    new_status = if article.status == "published", do: "draft", else: "published"

    attrs = %{
      "status" => new_status,
      "published_at" => if(new_status == "published", do: DateTime.utc_now(), else: nil)
    }

    case Blog.update_article(article, attrs) do
      {:ok, updated_article} ->
        message = if new_status == "published", do: "Article published", else: "Article unpublished"

        {:noreply,
         socket
         |> stream_insert(:articles, updated_article)
         |> put_flash(:info, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update article status")}
    end
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
