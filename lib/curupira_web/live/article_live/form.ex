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

    # Merge title into content for editing
    article_with_merged_content = merge_title_into_content(article)

    {:ok,
     socket
     |> assign(:article, article)
     |> assign(:form, to_form(Blog.change_article(article_with_merged_content)))
     |> assign(:preview_html, generate_preview_from_content(article_with_merged_content.content))}
  end

  @impl true
  def handle_event("validate", %{"article" => article_params}, socket) do
    changeset =
      socket.assigns.article
      |> Blog.change_article(article_params)
      |> Map.put(:action, :validate)

    preview_html = generate_preview_from_content(article_params["content"])

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:preview_html, preview_html)}
  end

  @impl true
  def handle_event("save", %{"article" => article_params}, socket) do
    article_params_with_title = extract_title_from_content(article_params)
    save_article(socket, socket.assigns.article.id, article_params_with_title)
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

  defp generate_preview_from_content(content) when is_binary(content) and content != "" do
    case Parser.to_html(content) do
      {:ok, html} -> html
      {:error, _} -> "<p class='text-red-500'>Error parsing markdown</p>"
    end
  end

  defp generate_preview_from_content(_content), do: ""

  defp merge_title_into_content(%Article{title: nil, content: content}), do: %Article{title: nil, content: content}
  defp merge_title_into_content(%Article{title: "", content: content}), do: %Article{title: "", content: content}
  defp merge_title_into_content(%Article{title: title, content: nil}) when is_binary(title) do
    %Article{title: title, content: "# #{title}"}
  end
  defp merge_title_into_content(%Article{title: title, content: content} = article) when is_binary(title) and is_binary(content) do
    merged_content = "# #{title}\n\n#{content}"
    %{article | content: merged_content}
  end

  defp extract_title_from_content(article_params) do
    content = article_params["content"] || ""
    {title, content_without_h1} = extract_and_remove_h1(content)

    article_params
    |> Map.put("title", title)
    |> Map.put("content", content_without_h1)
  end

  defp extract_and_remove_h1(content) when is_binary(content) do
    lines = String.split(content, "\n")

    case Enum.find_index(lines, fn line ->
      String.match?(String.trim(line), ~r/^#\s+.+$/)
    end) do
      nil ->
        {"Untitled", content}

      index ->
        h1_line = Enum.at(lines, index)
        title = String.replace(h1_line, ~r/^#\s+/, "") |> String.trim()

        content_without_h1 =
          lines
          |> List.delete_at(index)
          |> Enum.join("\n")
          |> String.trim()

        {title, content_without_h1}
    end
  end

  defp extract_and_remove_h1(_), do: {"Untitled", ""}
end
