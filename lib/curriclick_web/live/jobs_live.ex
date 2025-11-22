defmodule CurriclickWeb.JobsLive do
  use CurriclickWeb, :live_view

  alias Curriclick.Companies.{JobListing, JobApplication}
  require Ash.Query

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_optional}

  @page_size 20

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:ideal_job_description, "")
     |> assign(:current_page, 1)
     |> assign(:results, [])
     |> assign(:page_size, @page_size)
     |> assign(:submitted?, false)}
  end

  def handle_params(params, _url, socket) do
    case params["q"] do
      nil -> {:noreply, socket}
      "" -> {:noreply, socket}
      desc -> search_jobs(socket, desc)
    end
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
      {:noreply, push_patch(socket, to: ~p"/?#{[q: desc]}")}
    end
  end

  def handle_event("apply_to_job", %{"job_id" => job_id, "match" => match_score}, socket) do
    case socket.assigns[:current_user] do
      nil ->
        desc = socket.assigns.ideal_job_description
        return_to = ~p"/?#{[q: desc]}"
        {:noreply, redirect(socket, to: ~p"/sign-in?#{[return_to: return_to]}")}

      user ->
        match_score =
          case Float.parse(match_score) do
            {val, _} -> val
            :error -> nil
          end

        case JobApplication
             |> Ash.Changeset.for_create(:create, %{
               user_id: user.id,
               job_listing_id: job_id,
               search_query: socket.assigns.ideal_job_description,
               match_score: match_score
             })
             |> Ash.create() do
          {:ok, _} ->
            {:noreply, put_flash(socket, :info, "Candidatura enviada com sucesso!")}

          {:error, _} ->
            {:noreply,
             put_flash(socket, :info, "Você já se candidatou a esta vaga ou ocorreu um erro.")}
        end
    end
  end

  def handle_event("apply_to_all_matches", _params, socket) do
    case socket.assigns[:current_user] do
      nil ->
        desc = socket.assigns.ideal_job_description
        return_to = ~p"/?#{[q: desc]}"
        {:noreply, redirect(socket, to: ~p"/sign-in?#{[return_to: return_to]}")}

      user ->
        results = socket.assigns.results

        count =
          Enum.reduce(results, 0, fn job, acc ->
            case JobApplication
                 |> Ash.Changeset.for_create(:create, %{
                   user_id: user.id,
                   job_listing_id: job.id,
                   search_query: socket.assigns.ideal_job_description,
                   match_score: job.match
                 })
                 |> Ash.create() do
              {:ok, _} -> acc + 1
              _ -> acc
            end
          end)

        message =
          if count > 0 do
            "Candidatura enviada para #{count} novas vagas!"
          else
            "Nenhuma nova candidatura enviada (provavelmente já enviada anteriormente)."
          end

        {:noreply, put_flash(socket, :info, message)}
    end
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, assign(socket, :current_page, max(socket.assigns.current_page - 1, 1))}
  end

  def handle_event("next_page", _params, socket) do
    total_pages = total_pages(socket.assigns.results, socket.assigns.page_size)
    {:noreply, assign(socket, :current_page, min(socket.assigns.current_page + 1, total_pages))}
  end

  defp search_jobs(socket, desc) do
    query =
      JobListing
      |> Ash.Query.for_read(:find_matching_jobs, %{ideal_job_description: desc, limit: @page_size})
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
    <div class="h-[calc(100vh-10rem)] flex flex-col max-w-5xl mx-auto">
      <div class="flex-1 overflow-y-auto p-4 space-y-6 scroll-smooth">
        <%= if !@submitted? do %>
          <div class="hero h-full min-h-[50vh]">
            <div class="hero-content text-center">
              <div class="max-w-md">
                <div class="mb-6 inline-block p-4 bg-primary/10 rounded-full text-primary">
                  <.icon name="hero-sparkles" class="w-12 h-12" />
                </div>
                <h1 class="text-3xl font-bold">Encontre o emprego dos seus sonhos</h1>
                <p class="py-6 text-base-content/70">
                  Descreva sua função ideal, habilidades e preferências.
                  <br />Nossa IA irá conectar você com as melhores oportunidades.
                </p>
              </div>
            </div>
          </div>
        <% else %>
          <!-- User Message -->
          <div class="chat chat-end">
            <div class="chat-image avatar placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-10">
                <span class="text-xs">VOCÊ</span>
              </div>
            </div>
            <div class="chat-bubble chat-bubble-primary text-primary-content">
              {@ideal_job_description}
            </div>
          </div>
          
    <!-- AI Response -->
          <div class="chat chat-start">
            <div class="chat-image avatar">
              <div class="w-10 rounded-full bg-base-200 p-1 border border-base-300">
                <img src={~p"/images/logo.svg"} alt="AI" />
              </div>
            </div>
            <div class="chat-header opacity-50 mb-1">
              Curriclick IA
            </div>

            <%= if @results == [] do %>
              <div class="chat-bubble bg-base-200 text-base-content">
                Não encontrei nenhuma vaga correspondente a essa descrição. Tente buscar por palavras-chave ou tecnologias diferentes.
              </div>
            <% else %>
              <div class="flex flex-col gap-4 w-full max-w-3xl">
                <div class="chat-bubble bg-base-200 text-base-content">
                  Encontrei {length(@results)} vagas que correspondem aos seus critérios:
                  <button class="btn btn-xs btn-primary ml-2" phx-click="apply_to_all_matches">
                    Candidatar-se a todas
                  </button>
                </div>

                <div class="grid grid-cols-1 gap-4 mt-2">
                  <%= for job <- page_slice(@results, @current_page, @page_size) do %>
                    <div class="card bg-base-100 shadow-md border border-base-200 hover:border-primary/50 transition-colors group">
                      <div class="card-body p-5">
                        <div class="flex justify-between items-start gap-4">
                          <div>
                            <h3 class="font-bold text-lg group-hover:text-primary transition-colors">
                              {job.title}
                            </h3>
                            <p class="text-sm font-medium opacity-70 flex items-center gap-1">
                              <.icon name="hero-building-office-2" class="w-4 h-4" />
                              {job.company}
                            </p>
                          </div>
                          <div class="badge badge-primary badge-lg font-bold">{job.match}%</div>
                        </div>

                        <p class="text-sm mt-3 text-base-content/80 line-clamp-2">
                          {job.description}
                        </p>

                        <div class="card-actions justify-end mt-4 items-center border-t border-base-200 pt-3 gap-2">
                          <button class="btn btn-sm btn-ghost text-primary hover:bg-primary/10">
                            Ver Detalhes
                          </button>
                          <button
                            class="btn btn-sm btn-primary"
                            phx-click="apply_to_job"
                            phx-value-job_id={job.id}
                            phx-value-match={job.match}
                          >
                            Candidatar-se
                          </button>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <div class="flex justify-between items-center bg-base-200/50 p-2 rounded-lg">
                  <button
                    class="btn btn-xs btn-ghost"
                    phx-click="prev_page"
                    disabled={@current_page == 1}
                  >
                    <.icon name="hero-chevron-left" class="w-4 h-4" /> Anterior
                  </button>
                  <span class="text-xs opacity-50">
                    Página {@current_page} de {total_pages(@results, @page_size)}
                  </span>
                  <button
                    class="btn btn-xs btn-ghost"
                    phx-click="next_page"
                    disabled={@current_page >= total_pages(@results, @page_size)}
                  >
                    Próximo <.icon name="hero-chevron-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
      
    <!-- Input Area -->
      <div class="p-4 bg-base-100/80 backdrop-blur-md sticky bottom-0 z-10">
        <form phx-submit="submit_form" class="max-w-3xl mx-auto relative">
          <div class="join w-full shadow-lg rounded-2xl border border-base-300 bg-base-100 p-1.5">
            <!-- Filter Toggle -->
            <div class="dropdown dropdown-top dropdown-hover join-item">
              <div tabindex="0" role="button" class="btn btn-ghost btn-circle btn-sm h-full w-10">
                <.icon name="hero-adjustments-horizontal" class="w-5 h-5 opacity-70" />
              </div>
              <div
                tabindex="0"
                class="dropdown-content z-[10] card card-compact w-64 p-2 shadow-xl bg-base-100 border border-base-200 mb-2 ml-2"
              >
                <div class="card-body">
                  <h3 class="font-bold text-sm text-base-content/70 mb-1">Preferências</h3>
                  <div class="form-control">
                    <label class="label cursor-pointer justify-start gap-3 py-1">
                      <input type="checkbox" class="checkbox checkbox-xs checkbox-primary" checked />
                      <span class="label-text text-xs">Remoto</span>
                    </label>
                  </div>
                  <div class="form-control">
                    <label class="label cursor-pointer justify-start gap-3 py-1">
                      <input type="checkbox" class="checkbox checkbox-xs checkbox-primary" />
                      <span class="label-text text-xs">Híbrido</span>
                    </label>
                  </div>
                  <div class="divider my-1"></div>
                  <select class="select select-bordered select-xs w-full">
                    <option disabled selected>Senioridade</option>
                    <option>Júnior</option>
                    <option>Pleno</option>
                    <option>Sênior</option>
                  </select>
                </div>
              </div>
            </div>

            <input
              type="text"
              name="ideal_job_description"
              class="input input-ghost join-item w-full focus:outline-none focus:bg-transparent h-auto py-3 text-base"
              placeholder="Digite a descrição do seu trabalho ideal..."
              autocomplete="off"
              value={@ideal_job_description}
            />

            <button type="submit" class="btn btn-primary btn-circle btn-sm h-9 w-9 self-center mr-1">
              <.icon name="hero-arrow-up" class="w-4 h-4" />
            </button>
          </div>
          <div class="text-center mt-2">
            <span class="text-[10px] opacity-50">
              A busca de empregos por IA pode cometer erros. Verifique informações importantes.
            </span>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
