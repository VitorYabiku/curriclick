defmodule CurriclickWeb.JobsLive do
  use CurriclickWeb, :live_view

  alias Curriclick.Companies.JobListing
  require Ash.Query

  @page_size 10

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:ideal_job_description, "")
     |> assign(:current_page, 1)
     |> assign(:results, [])
     |> assign(:page_size, @page_size)
     |> assign(:submitted?, false)}
  end

  def handle_event("submit_form", %{"ideal_job_description" => desc}, socket) do
    desc = String.trim(desc || "")

    if desc == "" do
      {:noreply,
       socket
       |> assign(:ideal_job_description, desc)
       |> assign(:submitted?, true)
       |> assign(:current_page, 1)
       |> assign(:results, [])}
    else
      query =
        JobListing
        |> Ash.Query.for_read(:find_matching_jobs, %{ideal_job_description: desc, limit: 50})
        |> Ash.Query.load([:company])

      case Ash.read(query) do
        {:ok, records} ->
          results =
            Enum.map(records, fn r ->
              score =
                case r.match_score do
                  nil -> 0.0
                  val when is_float(val) -> Float.round(val * 100.0, 1)
                  val when is_integer(val) -> val * 1.0
                end

              %{
                id: r.id,
                title: r.job_role_name,
                company: (r.company && r.company.name) || "",
                description: r.description,
                match: score
              }
            end)

          {:noreply,
           socket
           |> assign(:ideal_job_description, desc)
           |> assign(:submitted?, true)
           |> assign(:current_page, 1)
           |> assign(:results, results)}

        {:error, error} ->
          message = Exception.message(error)

          {:noreply,
           socket
           |> put_flash(:error, message)
           |> assign(:ideal_job_description, desc)
           |> assign(:submitted?, true)
           |> assign(:current_page, 1)
           |> assign(:results, [])}
      end
    end
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, assign(socket, :current_page, max(socket.assigns.current_page - 1, 1))}
  end

  def handle_event("next_page", _params, socket) do
    total_pages = total_pages(socket.assigns.results, socket.assigns.page_size)
    {:noreply, assign(socket, :current_page, min(socket.assigns.current_page + 1, total_pages))}
  end

  defp total_pages(results, page_size) do
    count = length(results)
    if count == 0, do: 1, else: div(count + page_size - 1, page_size)
  end

  defp page_slice(results, page, page_size) do
    start = (page - 1) * page_size
    Enum.slice(results, start, page_size)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100">
      <div class="navbar bg-base-100 border-b border-base-300">
        <div class="flex-1">
          <a class="btn btn-ghost text-xl">Curriclick</a>
        </div>
        <div class="flex-none">
          <button class="btn btn-ghost">Entrar</button>
        </div>
      </div>

      <div class="container mx-auto px-4 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-4 gap-6">
          <aside class="lg:col-span-1 space-y-4">
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body gap-3">
                <h2 class="card-title text-base-content">Filtros</h2>
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input type="checkbox" class="checkbox checkbox-sm" />
                    <span class="label-text">Remoto</span>
                  </label>
                </div>
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input type="checkbox" class="checkbox checkbox-sm" />
                    <span class="label-text">Híbrido</span>
                  </label>
                </div>
                <div class="form-control">
                  <label class="label cursor-pointer justify-start gap-3">
                    <input type="checkbox" class="checkbox checkbox-sm" />
                    <span class="label-text">Presencial</span>
                  </label>
                </div>
                <div class="divider my-2"></div>
                <div class="form-control">
                  <label class="label"><span class="label-text">Senioridade</span></label>
                  <select class="select select-bordered select-sm">
                    <option>Qualquer</option>
                    <option>Júnior</option>
                    <option>Pleno</option>
                    <option>Sênior</option>
                  </select>
                </div>
              </div>
            </div>
          </aside>

          <main class="lg:col-span-3 space-y-6">
            <div class="card bg-base-100 border border-base-300">
              <div class="card-body gap-4">
                <h2 class="card-title">Seu objetivo profissional</h2>
                <form phx-submit="submit_form" class="space-y-2">
                  <div class="form-control">
                    <textarea name="ideal_job_description" rows="4" placeholder="Descreva a vaga ideal para você (ex.: área, senioridade, tecnologias, tipo de trabalho)" class="textarea textarea-bordered"></textarea>
                    <label class="label">
                      <span class="label-text-alt">Máximo de 2000 caracteres</span>
                    </label>
                  </div>
                  <div class="flex items-center gap-2 flex-wrap">
                    <button type="submit" class="btn btn-primary">
                      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4 mr-1"><path d="M12 2a1 1 0 0 1 .894.553l2.382 4.764 5.26.764a1 1 0 0 1 .554 1.706l-3.806 3.709.898 5.235a1 1 0 0 1-1.452 1.054L12 18.347l-4.68 2.438a1 1 0 0 1-1.452-1.054l.898-5.235L2.96 9.787a1 1 0 0 1 .554-1.706l5.26-.764L11.106 2.553A1 1 0 0 1 12 2z"/></svg>
                      Buscar vagas compatíveis
                    </button>
                  </div>
                </form>
              </div>
            </div>

            <div class="card bg-base-100 border border-dashed border-base-300">
              <div class="card-body">
                <div class="flex items-center gap-2">
                  <span class="badge badge-primary badge-sm"></span>
                  <span class="font-medium">Em breve:</span>
                  <span class="text-base-content/70">Recomendações por IA</span>
                </div>
              </div>
            </div>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <h2 class="text-2xl font-semibold">
                  <%= if @ideal_job_description != "" do %>
                    Vagas Recomendadas
                  <% else %>
                    Vagas
                  <% end %>
                </h2>
                <p class="text-sm text-base-content/60">
                  <%= if @ideal_job_description != "" do %>
                    <%= length(@results) %> vagas recomendadas
                  <% else %>
                    0 vagas
                  <% end %>
                </p>
              </div>

              <%= if @ideal_job_description == "" and @submitted? do %>
                <div class="card bg-base-100 border border-base-300 text-center py-16">
                  <div class="card-body items-center">
                    <h3 class="text-2xl text-base-content/70">Nenhuma vaga</h3>
                    <p class="text-base-content/60">Digite sua descrição ideal para ver vagas recomendadas por IA.</p>
                  </div>
                </div>
              <% else %>
                <%= if @ideal_job_description == "" do %>
                  <div class="card bg-base-100 border border-base-300 text-center py-16">
                    <div class="card-body items-center">
                      <h3 class="text-2xl text-base-content/70">Nenhuma vaga</h3>
                      <p class="text-base-content/60">Digite sua descrição ideal para ver vagas recomendadas por IA.</p>
                    </div>
                  </div>
                <% else %>
                  <div class="grid grid-cols-1 gap-4">
                    <%= for job <- page_slice(@results, @current_page, @page_size) do %>
                      <div class="card bg-base-100 border border-base-300">
                        <div class="card-body gap-2">
                          <div class="flex items-center justify-between gap-2">
                            <h3 class="card-title"><%= job.title %></h3>
                            <div class="flex items-center gap-2">
                              <div class="tooltip" data-tip="Compatibilidade">
                                <div class="badge badge-primary badge-outline"><%= job.match %>%</div>
                              </div>
                              <button class="btn btn-sm">Detalhes</button>
                            </div>
                          </div>
                          <p class="text-base-content/70"><%= job.company %></p>
                          <p class="text-base-content/80"><%= job.description %></p>
                          <progress class="progress progress-primary w-full" value={job.match} max="100"></progress>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>

              <div class="flex items-center justify-between px-2 py-4">
                <div class="text-sm text-base-content/60">
                  Página <%= @current_page %> de <%= total_pages(@results, @page_size) %>
                </div>
                <div class="btn-group">
                  <button class="btn btn-outline btn-sm" phx-click="prev_page" disabled={@current_page == 1}>
                    « Anterior
                  </button>
                  <button class="btn btn-outline btn-sm" phx-click="next_page" disabled={@current_page >= total_pages(@results, @page_size)}>
                    Próxima »
                  </button>
                </div>
              </div>
            </div>
          </main>
        </div>
      </div>
    </div>
    """
  end
end
