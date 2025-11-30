defmodule CurriclickWeb.UserDashboardLive do
  @moduledoc """
  LiveView for the user's dashboard (viewing applications).
  """
  use CurriclickWeb, :live_view

  alias Curriclick.Companies.JobApplication
  require Ash.Query

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    applications =
      JobApplication
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.load([:conversation, job_listing: :company])
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.read!()

    {:ok,
     socket
     |> assign(applications: applications)
     |> assign(expanded_ids: MapSet.new())
     |> assign(:selected_ids, MapSet.new())
     |> assign(:sort_by, :date)
     |> assign(:sort_order, :desc)}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)

    # Toggle order if clicking the same sort
    sort_order =
      if socket.assigns.sort_by == sort_by && socket.assigns.sort_order == :desc do
        :asc
      else
        :desc
      end

    sorted_applications = sort_applications(socket.assigns.applications, sort_by, sort_order)

    {:noreply,
     socket
     |> assign(sort_by: sort_by)
     |> assign(sort_order: sort_order)
     |> assign(applications: sorted_applications)}
  end

  def handle_event("toggle_selection", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    new_selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  def handle_event("batch_unapply", _, socket) do
    selected_ids = socket.assigns.selected_ids

    if MapSet.size(selected_ids) == 0 do
      {:noreply, socket}
    else
      # We do this one by one for now, but could be a bulk delete
      results =
        Enum.map(selected_ids, fn id ->
          case Ash.get(JobApplication, id) do
            {:ok, app} -> Ash.destroy(app)
            _ -> {:error, :not_found}
          end
        end)

      success_count = Enum.count(results, &match?(:ok, &1))

      remaining_applications =
        Enum.reject(socket.assigns.applications, fn app ->
          MapSet.member?(selected_ids, app.id)
        end)

      {:noreply,
       socket
       |> put_flash(:info, "#{success_count} candidaturas canceladas.")
       |> assign(:applications, remaining_applications)
       |> assign(:selected_ids, MapSet.new())}
    end
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

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto p-4">
      <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <h1 class="text-3xl font-bold">Minhas Candidaturas</h1>

        <div class="flex items-center gap-3">
          <!-- Sort Dropdown -->
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-2">
              <.icon
                name={if @sort_order == :asc, do: "hero-bars-arrow-up", else: "hero-bars-arrow-down"}
                class="w-4 h-4"
              /> Ordenar por: {format_sort_label(@sort_by)}
            </div>
            <ul
              tabindex="0"
              class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52"
            >
              <li>
                <button
                  phx-click="sort"
                  phx-value-sort_by="date"
                  class={if @sort_by == :date, do: "active"}
                >
                  Data de candidatura
                </button>
              </li>
              <li>
                <button
                  phx-click="sort"
                  phx-value-sort_by="match"
                  class={if @sort_by == :match, do: "active"}
                >
                  Compatibilidade
                </button>
              </li>
              <li>
                <button
                  phx-click="sort"
                  phx-value-sort_by="probability"
                  class={if @sort_by == :probability, do: "active"}
                >
                  Probabilidade de contratação
                </button>
              </li>
            </ul>
          </div>
        </div>
      </div>
      
    <!-- Batch Actions -->
      <%= if MapSet.size(@selected_ids) > 0 do %>
        <div class="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 animate-fade-in-up">
          <div class="bg-base-100 shadow-lg border border-base-300 rounded-full px-6 py-3 flex items-center gap-4">
            <span class="font-medium text-sm">{MapSet.size(@selected_ids)} selecionadas</span>
            <div class="h-4 w-px bg-base-300"></div>
            <button
              class="btn btn-sm btn-error btn-ghost text-error"
              phx-click="batch_unapply"
              data-confirm={"Tem certeza que deseja cancelar #{MapSet.size(@selected_ids)} candidaturas?"}
            >
              Cancelar candidaturas
            </button>
          </div>
        </div>
      <% end %>

      <div class="grid gap-4">
        <%= for app <- @applications do %>
          <div class={[
            "card bg-base-100 shadow-md border border-base-200 transition-colors transition-shadow duration-200",
            MapSet.member?(@selected_ids, app.id) && "border-primary ring-1 ring-primary bg-primary/5"
          ]}>
            <div
              class="card-body p-5 cursor-pointer"
              phx-click="toggle_expand"
              phx-value-id={app.id}
            >
              <!-- Header Section (Selects) -->
              <div
                class="flex justify-between items-start gap-4 -m-2 p-2 rounded-xl hover:bg-base-200/50 transition-colors mb-2"
                phx-click="toggle_selection"
                phx-value-id={app.id}
                phx-click-stop
              >
                <!-- Checkbox -->
                <div class="pt-1">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-primary checkbox-sm rounded-md pointer-events-none"
                    checked={MapSet.member?(@selected_ids, app.id)}
                  />
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex flex-wrap items-center gap-x-3 gap-y-1 mb-1">
                    <h2 class="card-title text-xl">{app.job_listing.title}</h2>
                  <div class="flex items-center gap-2">
                    <.match_quality_badge
                      quality={app.match_quality && app.match_quality.score}
                      explanation={app.match_quality && app.match_quality.explanation}
                    />
                    <%= if app.hiring_probability do %>
                        <span class={[
                            "badge badge-lg font-medium gap-1 cursor-help",
                            probability_color(app.hiring_probability.score)
                          ]}
                          data-smart-tooltip={app.hiring_probability.explanation}
                        >
                          Chance {format_probability(app.hiring_probability.score)}
                        </span>
                      <% end %>
                    </div>
                  </div>
                  <p class="text-base font-medium opacity-70 flex items-center gap-1 mt-1">
                    <.icon name="hero-building-office-2" class="w-4 h-4" />
                    {app.job_listing.company.name}
                  </p>
                </div>
                
    <!-- Right Side Actions (Collapsed) -->
                <div class="flex flex-col items-end gap-2">
                  <div class="text-xs opacity-50 whitespace-nowrap">
                    {Calendar.strftime(app.inserted_at, "%d/%m/%Y")}
                  </div>
                </div>
              </div>
              
    <!-- Summary Section (Expands via parent) -->
              <div class="pl-9">
                <div class="mt-1">
                  <!-- Keywords Badges -->
                  <%= if app.keywords && app.keywords != [] do %>
                    <div class="flex flex-wrap gap-1 mb-2">
                      <% keywords_to_show =
                        if MapSet.member?(@expanded_ids, app.id),
                          do: app.keywords,
                          else: Enum.take(app.keywords, 5) %>
                      <%= for keyword <- keywords_to_show do %>
                        <span class="badge badge-ghost badge-md cursor-help" data-smart-tooltip={keyword["explanation"]}>
                          {keyword["term"]}
                        </span>
                      <% end %>
                      <%= if !MapSet.member?(@expanded_ids, app.id) && length(app.keywords) > 5 do %>
                        <span class="badge badge-ghost badge-xs text-base-content/60">
                          +{length(app.keywords) - 5}
                        </span>
                      <% end %>
                    </div>
                  <% end %>

                  <%= if !MapSet.member?(@expanded_ids, app.id) do %>
                    <!-- Summary (truncated) instead of Description -->
                    <p class="text-sm text-base-content/70 line-clamp-2">
                      {app.summary || app.job_listing.description}
                    </p>
                  <% end %>
                </div>

                <%= if !MapSet.member?(@expanded_ids, app.id) do %>
                  <div class="mt-2 text-xs text-center opacity-40 flex items-center justify-center gap-1">
                    Ver mais detalhes <.icon name="hero-chevron-down" class="w-3 h-3" />
                  </div>
                <% end %>
              </div>
              
    <!-- Expanded Content -->
          <%= if MapSet.member?(@expanded_ids, app.id) do %>
            <div class="animate-fade-in space-y-6 cursor-auto" phx-click-stop>
              <div class="divider my-2"></div>
                  
    <!-- Conversation Link -->
                  <%= if app.conversation do %>
                    <.link
                      href={~p"/chat/#{app.conversation.id}"}
                      target="_blank"
                      class="alert alert-info bg-info/10 border-info/20 py-3 text-sm flex items-center justify-between hover:bg-info/20 transition-colors cursor-pointer group text-inherit hover:text-inherit"
                    >
                      <div class="flex items-center gap-2">
                        <.icon name="hero-chat-bubble-left-right" class="w-5 h-5 text-info" />
                        <span>
                          Vaga encontrada na conversa
                          <strong>{app.conversation.title || "Conversa sem título"}</strong>
                        </span>
                      </div>
                      <span class="btn btn-xs btn-info btn-outline group-hover:btn-active">
                        Ver conversa
                        <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3 ml-1" />
                      </span>
                    </.link>
                  <% else %>
                    <div class="alert bg-base-200/50 border-base-300 py-3 text-sm text-base-content/60 flex items-center gap-2">
                      <.icon name="hero-archive-box-x-mark" class="w-5 h-5" />
                      <span>A conversa original foi excluída.</span>
                    </div>
                  <% end %>
                  
    <!-- Meta Info & Badges -->

    <!-- Summary -->
                  <%= if app.summary do %>
                    <div class="bg-primary/5 rounded-2xl p-6 border border-primary/10">
                      <h3 class="font-semibold text-primary mb-2">Resumo</h3>
                      <p class="text-base leading-relaxed">{app.summary}</p>
                    </div>
                  <% end %>
                  
    <!-- Pros & Cons -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <%= if app.pros && app.pros != [] do %>
                      <div class="bg-base-200/30 rounded-2xl p-6">
                        <h4 class="font-semibold text-success flex items-center gap-2 mb-4">
                          <.icon name="hero-check-circle" class="w-5 h-5" /> Pontos Positivos
                        </h4>
                        <ul class="space-y-3">
                          <%= for pro <- app.pros do %>
                            <li class="text-base-content/80 flex items-start gap-3">
                              <span class="text-success mt-1">•</span>
                              <span>{pro}</span>
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>

                    <%= if app.cons && app.cons != [] do %>
                      <div class="bg-base-200/30 rounded-2xl p-6">
                        <h4 class="font-semibold text-warning flex items-center gap-2 mb-4">
                          <.icon name="hero-exclamation-triangle" class="w-5 h-5" /> Pontos de Atenção
                        </h4>
                        <ul class="space-y-3">
                          <%= for con <- app.cons do %>
                            <li class="text-base-content/80 flex items-start gap-3">
                              <span class="text-warning mt-1">•</span>
                              <span>{con}</span>
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>
                  </div>
                  
              <!-- Full Description Card -->
              <div class="card bg-base-200/30 border border-base-200">
                <div class="card-body p-6">
                  <h3 class="card-title text-lg mb-4 flex items-center gap-2">
                    <.icon name="hero-information-circle" class="w-5 h-5" />
                    Detalhes da Vaga
                  </h3>

                  <!-- Job Details List -->
                  <div class="mb-6 bg-base-100/50 rounded-xl p-4 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm border border-base-200/50">
                    <!-- Remote/On-site -->
                    <div class="flex items-center gap-2">
                      <.icon name="hero-home" class="w-4 h-4 opacity-70" />
                      <%= cond do %>
                        <% app.job_listing.remote_allowed == true -> %>
                          <span>Remoto</span>
                        <% app.job_listing.remote_allowed == false -> %>
                          <span>Presencial</span>
                        <% true -> %>
                          <span class="text-base-content/40 italic">Modalidade não informada</span>
                      <% end %>
                      <%= if app.remote_score do %>
                        <.match_quality_badge quality={app.remote_score.score} explanation={app.remote_score.explanation} styling="badge badge-sm font-normal" />
                      <% end %>
                    </div>

                    <!-- Work Type -->
                    <div class="flex items-center gap-2">
                      <.icon name="hero-briefcase" class="w-4 h-4 opacity-70" />
                      <%= if app.job_listing.work_type do %>
                        <span>{format_work_type(app.job_listing.work_type)}</span>
                      <% else %>
                        <span class="text-base-content/40 italic">Tipo de contrato não informado</span>
                      <% end %>
                      <%= if app.work_type_score do %>
                        <.match_quality_badge quality={app.work_type_score.score} explanation={app.work_type_score.explanation} styling="badge badge-sm font-normal" />
                      <% end %>
                    </div>

                    <!-- Salary -->
                    <div class="flex items-center gap-2">
                      <.icon name="hero-currency-dollar" class="w-4 h-4 opacity-70" />
                      <%= if format_salary(app.job_listing) do %>
                        <span>{format_salary(app.job_listing)}</span>
                      <% else %>
                        <span class="text-base-content/40 italic">Salário não informado</span>
                      <% end %>
                      <%= if app.salary_score do %>
                        <.match_quality_badge quality={app.salary_score.score} explanation={app.salary_score.explanation} styling="badge badge-sm font-normal" />
                      <% end %>
                    </div>

                    <!-- Location -->
                    <div class="flex items-center gap-2">
                      <.icon name="hero-map-pin" class="w-4 h-4 opacity-70" />
                      <%= if app.job_listing.location do %>
                        <span>{app.job_listing.location}</span>
                      <% else %>
                        <span class="text-base-content/40 italic">Localização não informada</span>
                      <% end %>
                      <%= if app.location_score do %>
                        <.match_quality_badge quality={app.location_score.score} explanation={app.location_score.explanation} styling="badge badge-sm font-normal" />
                      <% end %>
                    </div>
                  </div>

                  <!-- Skills -->
                  <div class="mb-6">
                    <h3 class="font-bold text-sm mb-2 flex items-center gap-2">
                      <.icon name="hero-sparkles" class="w-4 h-4" /> Habilidades Necessárias
                      <%= if app.skills_score do %>
                        <.match_quality_badge quality={app.skills_score.score} explanation={app.skills_score.explanation} styling="badge badge-sm font-normal" />
                      <% end %>
                    </h3>
                    <%= if app.job_listing.skills_desc do %>
                      <p class="text-sm text-base-content/80">{app.job_listing.skills_desc}</p>
                    <% else %>
                      <p class="text-sm text-base-content/40 italic">Habilidades não informadas</p>
                    <% end %>
                  </div>
                  
                  <div class="divider opacity-50"></div>

                  <!-- Description -->
                  <h3 class="font-bold text-sm mb-4 flex items-center gap-2">
                    <.icon name="hero-document-text" class="w-4 h-4" /> Descrição Completa
                  </h3>
                  <%= if app.job_listing.description do %>
                    <div class="markdown-content text-sm opacity-90">
                      {to_markdown(app.job_listing.description)}
                    </div>
                  <% else %>
                    <p class="text-sm text-base-content/40 italic">Descrição não informada</p>
                  <% end %>
                </div>
              </div>

                  <div class="flex justify-end pt-2">
                    <button
                      class="btn btn-error btn-outline btn-sm"
                      phx-click="unapply"
                      phx-value-id={app.id}
                      data-confirm="Tem certeza que deseja cancelar sua candidatura? Esta ação não pode ser desfeita."
                    >
                      Cancelar candidatura
                    </button>
                  </div>
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

  # Match quality badge component
  attr :quality, :atom, required: true
  attr :styling, :string, default: "badge badge-lg font-medium"
  attr :explanation, :string, default: nil

  @spec match_quality_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def match_quality_badge(assigns) do
    {label, badge_class} =
      case assigns.quality do
        :good_match -> {"Boa compatibilidade", "badge-info"}
        :moderate_match -> {"Média compatibilidade", "badge-warning"}
        :bad_match -> {"Baixa compatibilidade", "badge-ghost"}
        _ -> {"--", "badge-ghost"}
      end

    assigns =
      assign(assigns,
        label: label,
        badge_class: badge_class,
        explanation: assigns.explanation,
        styling: assigns.styling
      )

    ~H"""
    <%= if @explanation do %>
      <span class={[@styling, @badge_class, "cursor-help"]} data-smart-tooltip={@explanation}>
        {@label}
      </span>
    <% else %>
      <span class={[@styling, @badge_class]}>
        {@label}
      </span>
    <% end %>
    """
  end

  @spec probability_color(atom()) :: String.t()
  defp probability_color(prob) do
    case prob do
      :high -> "badge-success"
      :medium -> "badge-warning"
      :low -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  @spec format_probability(atom()) :: String.t()
  defp format_probability(prob) do
    case prob do
      :high -> "Alta"
      :medium -> "Moderada"
      :low -> "Baixa"
      _ -> "--"
    end
  end

  @spec format_sort_label(atom()) :: String.t()
  defp format_sort_label(sort_by) do
    case sort_by do
      :date -> "Data"
      :match -> "Compatibilidade"
      :probability -> "Probabilidade"
    end
  end

  @spec sort_applications([map()], atom(), atom()) :: [map()]
  defp sort_applications(applications, :date, :asc),
    do: Enum.sort_by(applications, & &1.inserted_at, {:asc, DateTime})

  defp sort_applications(applications, :date, :desc),
    do: Enum.sort_by(applications, & &1.inserted_at, {:desc, DateTime})

  defp sort_applications(applications, :probability, :asc),
    do: Enum.sort_by(applications, &probability_score(&1.hiring_probability), :asc)

  defp sort_applications(applications, :probability, :desc),
    do: Enum.sort_by(applications, &probability_score(&1.hiring_probability), :desc)

  defp sort_applications(applications, :match, order) do
    Enum.sort_by(applications, fn app -> match_quality_score(app.match_quality) end, order)
  end

  @spec probability_score(map() | nil) :: integer()
  defp probability_score(%{score: :high}), do: 3
  defp probability_score(%{score: :medium}), do: 2
  defp probability_score(%{score: :low}), do: 1
  defp probability_score(_), do: 0

  @spec match_quality_score(map() | nil) :: integer()
  defp match_quality_score(%{score: :good_match}), do: 3
  defp match_quality_score(%{score: :moderate_match}), do: 2
  defp match_quality_score(%{score: :bad_match}), do: 1
  defp match_quality_score(_), do: 0

  @spec format_work_type(atom()) :: String.t()
  defp format_work_type(work_type) do
    case work_type do
      :FULL_TIME -> "Tempo integral"
      :PART_TIME -> "Meio período"
      :CONTRACT -> "Contrato"
      :INTERNSHIP -> "Estágio"
      :TEMPORARY -> "Temporário"
      _ -> to_string(work_type)
    end
  end

  @spec format_salary(Curriclick.Companies.JobListing.t()) :: String.t() | nil
  defp format_salary(listing) do
    if listing.min_salary do
      currency = listing.currency || "USD"
      period = listing.pay_period || "year"
      min = Decimal.to_string(listing.min_salary)

      if listing.max_salary do
        max = Decimal.to_string(listing.max_salary)
        "#{currency} #{min} - #{max} / #{period}"
      else
        "#{currency} #{min} / #{period}"
      end
    else
      nil
    end
  end

  @spec to_markdown(String.t()) :: Phoenix.HTML.Safe.t() | String.t()
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
