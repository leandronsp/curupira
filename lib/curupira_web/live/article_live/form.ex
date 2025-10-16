defmodule CurupiraWeb.ArticleLive.Form do
  use CurupiraWeb, :live_view

  alias Curupira.Blog
  alias Curupira.Blog.Article
  alias Curupira.Markdown.Parser

  @impl true
  def mount(params, _session, socket) do
    article =
      case params["id"] do
        nil -> %Article{}
        id -> Blog.get_article!(id)
      end

    {:ok,
     socket
     |> assign(:article, article)
     |> assign(:form, to_form(Blog.change_article(article)))
     |> assign(:preview_html, generate_preview(article.content))}
  end

  @impl true
  def handle_event("validate", %{"article" => article_params}, socket) do
    changeset =
      socket.assigns.article
      |> Blog.change_article(article_params)
      |> Map.put(:action, :validate)

    preview_html = generate_preview(article_params["content"])

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:preview_html, preview_html)}
  end

  @impl true
  def handle_event("save", %{"article" => article_params}, socket) do
    save_article(socket, socket.assigns.article.id, article_params)
  end

  defp save_article(socket, nil, article_params) do
    case Blog.create_article(article_params) do
      {:ok, article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article created successfully")
         |> push_navigate(to: ~p"/articles/#{article}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_article(socket, _id, article_params) do
    case Blog.update_article(socket.assigns.article, article_params) do
      {:ok, _article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp generate_preview(nil), do: ""
  defp generate_preview(""), do: ""
  defp generate_preview(markdown) do
    case Parser.to_html(markdown) do
      {:ok, html} -> html
      {:error, _} -> "<p class='text-red-500'>Error parsing markdown</p>"
    end
  end
end
