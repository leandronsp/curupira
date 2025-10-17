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
     |> assign(:preview_html, generate_preview(article.title, article.content))
     |> assign(:tag_input, "")
     |> assign(:layout_mode, "split")
     |> assign(:save_state, "idle")
     |> allow_upload(:images,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def handle_event("validate", %{"article" => article_params}, socket) do
    article_params = process_tags(article_params)

    changeset =
      socket.assigns.article
      |> Blog.change_article(article_params)
      |> Map.put(:action, :validate)

    preview_html = generate_preview(article_params["title"], article_params["content"])

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:preview_html, preview_html)}
  end

  defp handle_progress(:images, entry, socket) when entry.done? do
    uploaded_file =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        # Create uploads directory if it doesn't exist
        upload_dir = Path.join([:code.priv_dir(:curupira), "static", "uploads"])
        File.mkdir_p!(upload_dir)

        # Generate unique filename preserving extension
        ext = Path.extname(entry.client_name)
        filename = "#{System.unique_integer([:positive])}#{ext}"
        dest = Path.join(upload_dir, filename)

        # Copy file to permanent location
        case File.cp(path, dest) do
          :ok ->
            {:ok, "/uploads/#{filename}"}

          {:error, reason} ->
            require Logger
            Logger.error("Failed to save uploaded image: #{inspect(reason)}")
            {:postpone, :error}
        end
      end)

    {:noreply, push_event(socket, "image-uploaded", %{url: uploaded_file})}
  end

  defp handle_progress(:images, _entry, socket) do
    # Upload still in progress, do nothing
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"article" => article_params}, socket) do
    article_params = process_tags(article_params)
    save_article(socket, socket.assigns.article.id, article_params)
  end

  @impl true
  def handle_event("update_tag_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, :tag_input, value)}
  end

  @impl true
  def handle_event("add_tag", %{"value" => tag}, socket) do
    tag = String.trim(tag)

    if tag != "" do
      current_tags = get_current_tags(socket)
      new_tags = Enum.uniq(current_tags ++ [tag])

      changeset =
        socket.assigns.article
        |> Blog.change_article(%{"tags" => new_tags})
        |> Map.put(:action, :validate)

      {:noreply,
       socket
       |> assign(:form, to_form(changeset))
       |> assign(:tag_input, "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    current_tags = get_current_tags(socket)
    new_tags = Enum.reject(current_tags, &(&1 == tag))

    changeset =
      socket.assigns.article
      |> Blog.change_article(%{"tags" => new_tags})
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("remove_last_tag", _params, socket) do
    if socket.assigns.tag_input == "" do
      current_tags = get_current_tags(socket)

      if length(current_tags) > 0 do
        new_tags = Enum.drop(current_tags, -1)

        changeset =
          socket.assigns.article
          |> Blog.change_article(%{"tags" => new_tags})
          |> Map.put(:action, :validate)

        {:noreply, assign(socket, :form, to_form(changeset))}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_layout", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :layout_mode, mode)}
  end

  @impl true
  def handle_info(:reset_save_state, socket) do
    {:noreply, assign(socket, :save_state, "idle")}
  end

  defp save_article(socket, nil, article_params) do
    case Blog.create_article(article_params) do
      {:ok, article} ->
        Process.send_after(self(), :reset_save_state, 2000)

        {:noreply,
         socket
         |> put_flash(:info, "Article created successfully")
         |> assign(:save_state, "saved")
         |> push_navigate(to: ~p"/articles/#{article}/edit")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_article(socket, _id, article_params) do
    case Blog.update_article(socket.assigns.article, article_params) do
      {:ok, _article} ->
        Process.send_after(self(), :reset_save_state, 2000)

        {:noreply,
         socket
         |> put_flash(:info, "Article updated successfully")
         |> assign(:save_state, "saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp generate_preview(title, content) do
    full_markdown = build_full_markdown(title, content)

    case Parser.to_html(full_markdown) do
      {:ok, html} -> html
      {:error, _} -> "<p class='text-red-500'>Error parsing markdown</p>"
    end
  end

  defp build_full_markdown(nil, nil), do: ""
  defp build_full_markdown(nil, content) when is_binary(content), do: content
  defp build_full_markdown("", content) when is_binary(content), do: content
  defp build_full_markdown(title, nil) when is_binary(title), do: "# #{title}"
  defp build_full_markdown(title, "") when is_binary(title), do: "# #{title}"
  defp build_full_markdown(title, content) when is_binary(title) and is_binary(content) do
    "# #{title}\n\n#{content}"
  end
  defp build_full_markdown(_, _), do: ""

  defp process_tags(%{"tags_input" => tags_input} = params) when is_binary(tags_input) do
    tags =
      tags_input
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    params
    |> Map.delete("tags_input")
    |> Map.put("tags", tags)
  end
  defp process_tags(params), do: params

  defp tags_to_string(nil), do: ""
  defp tags_to_string([]), do: ""
  defp tags_to_string(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp tags_to_string(_), do: ""

  defp get_current_tags(socket) do
    case Ecto.Changeset.get_field(socket.assigns.form.source, :tags) do
      nil -> []
      tags when is_list(tags) -> tags
      _ -> []
    end
  end
end
