defmodule CurriclickWeb.UserDashboardLive do
  use CurriclickWeb, :live_view

  alias Curriclick.Companies.JobApplication
  require Ash.Query

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    applications =
      JobApplication
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.load(job_listing: :company)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok,
     socket
     |> assign(applications: applications)
     |> assign(expanded_ids: MapSet.new())}
  end

  def handle_event("toggle_expand", %{"id" => id}, socket) do
    expanded_ids = socket.assigns.expanded_ids

    new_expanded_ids =
      if MapSet.member?(expanded_ids, id) do
        MapSet.delete(expanded_ids, id)
      else
        MapSet.put(expanded_ids, id)
      end

    {:noreply, assign(socket, :expanded_ids, new_expanded_ids)}
  end

  def handle_event("unapply", %{"id" => id}, socket) do
    case Ash.get(JobApplication, id) do
      {:ok, application} ->
        case Ash.destroy(application) do
          :ok ->
            applications =
              Enum.reject(socket.assigns.applications, fn app -> app.id == id end)

            {:noreply,
             socket
             |> put_flash(:info, "Candidatura cancelada com sucesso.")
             |> assign(:applications, applications)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Erro ao cancelar candidatura.")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Candidatura não encontrada.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-4">
      <h1 class="text-3xl font-bold mb-8">Minhas Candidaturas</h1>

      <div class="grid gap-4">
        <%= for app <- @applications do %>
          <div
            class="card bg-base-100 shadow-md border border-base-200 cursor-pointer hover:shadow-lg transition-shadow"
            phx-click="toggle_expand"
            phx-value-id={app.id}
          >
            <div class="card-body p-5">
              <div class="flex justify-between items-start">
                <div>
                  <h2 class="card-title text-xl">{app.job_listing.title}</h2>
                  <p class="text-base font-medium opacity-70 flex items-center gap-1 mt-1">
                    <.icon name="hero-building-office-2" class="w-4 h-4" />
                    {app.job_listing.company.name}
                  </p>
                </div>
                <div class="flex flex-col items-end gap-2">
                  <div class="badge badge-primary badge-lg font-bold">
                    {app.match_score || 0}% match
                  </div>
                  <div class="flex items-center gap-3">
                    <div class="text-xs opacity-50">
                      Inscrito em {Calendar.strftime(app.inserted_at, "%d/%m/%Y às %H:%M UTC")}
                    </div>
                    <button
                      class="btn btn-xs btn-error btn-outline"
                      phx-click="unapply"
                      phx-click-stop
                      phx-value-id={app.id}
                      data-confirm="Tem certeza que deseja cancelar sua candidatura? Esta ação não pode ser desfeita."
                    >
                      Cancelar candidatura
                    </button>
                  </div>
                </div>
              </div>

              <%= if MapSet.member?(@expanded_ids, app.id) do %>
                <div class="mt-6 animate-fade-in">
                  <div class="divider my-2"></div>

                  <div class="mb-4">
                    <h3 class="font-bold text-sm mb-1">Sua busca original</h3>
                    <div class="bg-base-200 p-3 rounded-lg text-sm italic">
                      "{app.search_query || "N/A"}"
                    </div>
                  </div>

                  <div>
                    <h3 class="font-bold text-sm mb-2">Descrição da Vaga</h3>
                    <div class="markdown-content text-sm opacity-90">
                      {to_markdown(app.job_listing.description)}
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="mt-2 opacity-60 text-sm line-clamp-2">
                  {app.job_listing.description}
                </div>
                <div class="mt-2 text-xs text-center opacity-40 flex items-center justify-center gap-1">
                  Ver mais detalhes <.icon name="hero-chevron-down" class="w-3 h-3" />
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @applications == [] do %>
          <div class="text-center py-16 bg-base-200/50 rounded-xl border border-base-200 border-dashed">
            <div class="bg-base-200 p-4 rounded-full inline-block mb-4">
              <.icon name="hero-document-text" class="w-8 h-8 opacity-50" />
            </div>
            <h3 class="text-lg font-bold">Nenhuma candidatura encontrada</h3>
            <p class="text-base-content/70 mt-2 max-w-md mx-auto">
              Você ainda não se candidatou a nenhuma vaga. Utilize a busca para encontrar oportunidades que combinam com você.
            </p>
            <div class="mt-6">
              <.link navigate={~p"/chat"} class="btn btn-primary">
                Buscar Vagas
              </.link>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp to_markdown(text) do
    # Note that you must pass the "unsafe: true" option to first generate the raw HTML
    # in order to sanitize it. https://hexdocs.pm/mdex/MDEx.html#module-sanitize
    MDEx.to_html(text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        unsafe: true
      ],
      sanitize: MDEx.Document.default_sanitize_options()
    )
    |> case do
      {:ok, html} ->
        html
        |> Phoenix.HTML.raw()

      {:error, _} ->
        text
    end
  end
end
