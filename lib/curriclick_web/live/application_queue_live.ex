defmodule CurriclickWeb.ApplicationQueueLive do
  @moduledoc """
  LiveView for the application queue (draft applications).
  """
  use CurriclickWeb, :live_view

  alias Curriclick.Companies.JobApplication
  alias Curriclick.Companies.JobApplicationAnswer
  require Ash.Query

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "job_applications")
    end

    user = socket.assigns.current_user

    applications = fetch_applications(user.id)

    socket =
      socket
      |> assign(:applications, applications)
      |> assign(:selected_application_id, if(applications != [], do: hd(applications).id, else: nil))

    {:ok, socket}
  end

  def handle_info(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{}}, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :applications, fetch_applications(user.id))}
  end

  def handle_info({:application_updated, _id}, socket) do
    user = socket.assigns.current_user
    applications = fetch_applications(user.id)

    # Preserve selection or default to first if previous selection is gone (rare for update)
    selected_id = socket.assigns.selected_application_id || if(applications != [], do: hd(applications).id)

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> assign(:selected_application_id, selected_id)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case Ash.get(JobApplication, id) do
      {:ok, app} ->
        Ash.destroy!(app)

        applications = fetch_applications(socket.assigns.current_user.id)
        new_selected_id = if applications != [], do: hd(applications).id, else: nil

        {:noreply,
         socket
         |> put_flash(:info, "Candidatura removida da fila.")
         |> assign(:applications, applications)
         |> assign(:selected_application_id, new_selected_id)}

      _ ->
        {:noreply, put_flash(socket, :error, "Candidatura não encontrada.")}
    end
  end

  def handle_event("submit", %{"id" => id}, socket) do
    case Ash.get(JobApplication, id) do
      {:ok, app} ->
        # Check if all answers are filled
        answers = app.answers || []

        missing_answers =
          Enum.any?(answers, fn a -> is_nil(a.answer) or String.trim(a.answer) == "" end)

        if missing_answers do
          {:noreply,
           put_flash(socket, :error, "Por favor, preencha todas as respostas antes de enviar.")}
        else
           case Curriclick.Companies.JobApplication.submit(app) do
            {:ok, _} ->
              applications = fetch_applications(socket.assigns.current_user.id)
              new_selected_id = if applications != [], do: hd(applications).id, else: nil

              {:noreply,
               socket
               |> put_flash(:info, "Candidatura enviada com sucesso!")
               |> assign(:applications, applications)
               |> assign(:selected_application_id, new_selected_id)}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Erro ao enviar candidatura.")}
          end
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("update_answer", %{"id" => answer_id, "value" => value}, socket) do
    case Ash.get(JobApplicationAnswer, answer_id) do
      {:ok, answer} ->
        Curriclick.Companies.JobApplicationAnswer.update!(answer, %{answer: value})

        {:noreply,
         assign(socket, :applications, fetch_applications(socket.assigns.current_user.id))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("select_application", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_application_id, id)}
  end

  defp fetch_applications(user_id) do
    JobApplication
    |> Ash.Query.filter(user_id == ^user_id and status == :draft)
    |> Ash.Query.load([:conversation, answers: [:requirement], job_listing: [:company]])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end

  defp get_application_stats(app) do
    answers = app.answers || []

    missing_questions =
      answers
      |> Enum.filter(fn a -> is_nil(a.answer) or String.trim(a.answer) == "" end)
      |> Enum.map(fn a -> a.requirement.question end)

    missing_infos =
      answers
      |> Enum.filter(fn a -> not is_nil(a.missing_info) end)
      |> Enum.map(fn a -> a.missing_info end)

    low_confidence_count =
      Enum.count(answers, fn a -> a.confidence_score in [:low, :medium] end)

    %{
      missing_answers_count: length(missing_questions),
      missing_questions: missing_questions,
      missing_info_count: length(missing_infos),
      missing_infos: missing_infos,
      low_confidence_count: low_confidence_count
    }
  end

  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open h-[calc(100vh-4rem)] bg-base-100">
      <input id="app-queue-drawer" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col h-full overflow-hidden bg-base-100">
        <!-- Mobile Header -->
        <div class="navbar bg-base-100 w-full md:hidden border-b border-base-200 min-h-12">
          <div class="flex-none">
            <label for="app-queue-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost btn-sm">
              <.icon name="hero-bars-3" class="w-5 h-5" />
            </label>
          </div>
          <div class="flex-1 px-2 mx-2 text-sm font-semibold">Candidaturas</div>
        </div>

        <!-- Main Content Area -->
        <div class="flex-1 overflow-y-auto p-4 md:p-8">
          <% app = @selected_application_id && Enum.find(@applications, &(&1.id == @selected_application_id)) %>
          <%= if app do %>
            <div class="max-w-4xl mx-auto">
              <div class="flex justify-between items-start mb-6">
                <div>
                  <h2 class="text-2xl font-bold mb-1">{app.job_listing.title}</h2>
                  <p class="text-base-content/70">
                    {app.job_listing.company.name} • Criado em {Calendar.strftime(app.inserted_at, "%d/%m/%Y às %H:%M")}
                  </p>
                </div>
                <button
                  class="btn btn-sm btn-ghost text-error"
                  phx-click="remove"
                  phx-value-id={app.id}
                  data-confirm="Tem certeza que deseja remover esta candidatura da fila?"
                >
                  <.icon name="hero-trash" class="w-4 h-4" /> Remover
                </button>
              </div>

              <%= if app.answers == [] do %>
                <div class="flex items-center gap-3 py-12 justify-center text-base-content/60 bg-base-200/30 rounded-2xl">
                  <span class="loading loading-spinner loading-md"></span>
                  <span>Gerando respostas com IA...</span>
                </div>
              <% else %>
                <% issues =
                  Enum.filter(app.answers, fn a ->
                    a.confidence_score == :low or not is_nil(a.missing_info) or is_nil(a.answer)
                  end) %>

                <%= if issues != [] do %>
                  <div class="alert alert-warning mb-8 shadow-sm">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                    <div>
                      <h3 class="font-bold">Atenção necessária</h3>
                      <div class="text-sm">
                        <p>Encontramos {length(issues)} ponto(s) que precisam da sua revisão:</p>
                        <ul class="list-disc list-inside mt-1 opacity-80">
                          <%= for issue <- issues do %>
                            <li>
                              {String.slice(issue.requirement.question, 0, 40)}{if String.length(
                                                                                     issue.requirement.question
                                                                                   ) > 40,
                                                                                   do: "..."}
                              <%= if issue.confidence_score == :low do %>
                                <span class="badge badge-xs badge-error ml-1">Baixa confiança</span>
                              <% end %>
                              <%= if issue.missing_info do %>
                                <span class="badge badge-xs badge-warning ml-1">Info faltante</span>
                              <% end %>
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    </div>
                  </div>
                <% end %>

                <div class="space-y-8">
                  <%= for answer <- app.answers do %>
                    <div class={[
                      "form-control p-6 rounded-2xl transition-all shadow-sm bg-base-200/30 border",
                      if(answer.confidence_score == :low,
                        do: "border-error/50 bg-error/5",
                        else:
                          if(answer.confidence_score == :medium,
                            do: "border-warning/50 bg-warning/5",
                            else: "border-base-200"
                          )
                      )
                    ]}>
                      <div class="mb-4 flex justify-between items-start gap-4">
                        <span class="font-semibold text-lg leading-relaxed block text-base-content break-words flex-1">
                          {answer.requirement.question}
                        </span>
                        <.confidence_badge
                          score={answer.confidence_score}
                          explanation={answer.confidence_explanation}
                        />
                      </div>

                      <%= if answer.missing_info do %>
                        <div class="alert alert-warning py-2 px-4 mb-4 text-sm">
                          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
                          <span>
                            <strong>Informação faltante:</strong> {answer.missing_info}
                          </span>
                        </div>
                      <% end %>

                      <textarea
                        class={["textarea textarea-bordered h-32 w-full text-base leading-relaxed focus:border-primary focus:ring-1 focus:ring-primary bg-base-100"]}
                        placeholder={
                          if is_nil(answer.answer),
                            do: "Informação ausente. Por favor, preencha manualmente ou forneça as informações faltantes."
                        }
                        phx-blur="update_answer"
                        phx-value-id={answer.id}
                      >{answer.answer}</textarea>

                      <%= if answer.confidence_explanation && answer.confidence_score != :high do %>
                        <div class="mt-3 text-sm opacity-70 flex gap-2 items-start">
                          <.icon name="hero-information-circle" class="w-5 h-5 mt-0.5 flex-shrink-0" />
                          <span class="leading-relaxed">{answer.confidence_explanation}</span>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <div class="card-actions justify-end mt-8 pt-6 border-t border-base-200 sticky bottom-0 bg-base-100 pb-4 z-10">
                  <% missing_questions =
                    app.answers
                    |> Enum.filter(fn a -> is_nil(a.answer) or String.trim(a.answer) == "" end)
                    |> Enum.map(fn a -> a.requirement.question end)

                  has_missing = missing_questions != []

                  tooltip_msg =
                    if has_missing do
                      "Perguntas pendentes:\n" <>
                        Enum.map_join(missing_questions, "\n", fn q ->
                          "• " <> String.slice(q, 0, 30) <> if(String.length(q) > 30, do: "...", else: "")
                        end)
                    end %>
                  <div
                    class={if has_missing, do: "tooltip tooltip-left tooltip-error", else: ""}
                    data-tip={tooltip_msg}
                  >
                    <button
                      class="btn btn-primary btn-lg shadow-lg"
                      disabled={has_missing}
                      phx-click="submit"
                      phx-value-id={app.id}
                    >
                      Confirmar a Candidatura <.icon name="hero-paper-airplane" class="w-5 h-5 ml-2" />
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <%= if @applications == [] do %>
              <div class="text-center py-20">
                <div class="bg-base-200 p-6 rounded-full inline-block mb-6">
                  <.icon name="hero-inbox-stack" class="w-12 h-12 opacity-30" />
                </div>
                <h3 class="text-xl font-bold mb-2">Sua fila está vazia</h3>
                <p class="text-base-content/60 max-w-md mx-auto mb-8">
                  Adicione vagas à fila através da Busca de Empregos para revisar as respostas aqui antes de enviar.
                </p>
                <.link navigate={~p"/chat"} class="btn btn-primary">
                  Buscar Vagas
                </.link>
              </div>
            <% else %>
              <div class="flex items-center justify-center h-full text-base-content/50">
                Selecione uma candidatura para ver os detalhes
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <div class="drawer-side h-full z-20 absolute md:relative">
        <label for="app-queue-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <div class="menu p-4 w-80 md:w-96 h-full bg-base-200/50 border-r border-base-300 text-base-content flex flex-col">
          <div class="flex items-center justify-between mb-6 px-2">
            <h2 class="font-bold text-lg">Fila de Candidaturas</h2>
            <span class="badge badge-primary">{length(@applications)}</span>
          </div>

          <div class="flex-1 overflow-y-auto space-y-3 -mx-2 px-2">
            <%= for app <- @applications do %>
              <% stats = get_application_stats(app) %>
              <div
                class={[
                  "card bg-base-100 shadow-sm border transition-all cursor-pointer hover:border-primary/50 hover:shadow-md group text-left",
                  @selected_application_id == app.id && "border-primary ring-1 ring-primary bg-primary/5"
                ]}
                phx-click="select_application"
                phx-value-id={app.id}
              >
                <div class="card-body p-4 gap-2">
                  <div>
                    <h3 class="font-bold text-sm leading-tight">{app.job_listing.title}</h3>
                    <p class="text-xs text-base-content/60 mt-0.5">{app.job_listing.company.name}</p>
                  </div>

                  <!-- Stats -->
                  <div class="space-y-2 mt-2">
                    <%= if stats.missing_answers_count > 0 do %>
                      <div class="bg-error/10 rounded-lg p-2 border border-error/20">
                        <div class="text-error text-xs font-bold mb-1 flex items-center gap-1">
                          <.icon name="hero-pencil-square" class="w-3 h-3" />
                          {stats.missing_answers_count} perguntas pendentes
                        </div>
                        <ul class="list-disc list-inside text-[10px] opacity-80 space-y-0.5">
                          <%= for q <- Enum.take(stats.missing_questions, 2) do %>
                            <li class="truncate">{q}</li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>

                    <%= if stats.missing_info_count > 0 do %>
                      <div class="bg-warning/10 rounded-lg p-2 border border-warning/20">
                        <div class="text-warning-content text-xs font-bold mb-1 flex items-center gap-1">
                          <.icon name="hero-exclamation-triangle" class="w-3 h-3" />
                          {stats.missing_info_count} info faltante
                        </div>
                        <ul class="list-disc list-inside text-[10px] opacity-80 space-y-0.5">
                          <%= for info <- Enum.take(stats.missing_infos, 2) do %>
                            <li class="truncate">{info}</li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>

                    <%= if stats.low_confidence_count > 0 do %>
                      <div class="flex items-center gap-1 text-xs text-warning font-medium">
                        <.icon name="hero-sparkles" class="w-3 h-3" />
                        {stats.low_confidence_count} baixa/média confiança
                      </div>
                    <% end %>

                    <%= if stats.missing_answers_count == 0 && stats.missing_info_count == 0 && stats.low_confidence_count == 0 do %>
                      <div class="text-success text-xs font-bold flex items-center gap-1">
                        <.icon name="hero-check-circle" class="w-3 h-3" />
                        Pronto para enviar
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :score, :atom, required: true
  attr :explanation, :string, default: nil

  def confidence_badge(assigns) do
    {label, class, icon} =
      case assigns.score do
        :high -> {"Alta Confiança", "badge-success", "hero-check-circle"}
        :medium -> {"Média Confiança", "badge-warning", "hero-exclamation-circle"}
        :low -> {"Baixa Confiança", "badge-error", "hero-exclamation-triangle"}
        _ -> {"N/A", "badge-ghost", "hero-question-mark-circle"}
      end

    assigns = assign(assigns, label: label, class: class, icon: icon)

    ~H"""
    <div class={["badge badge-lg gap-2 py-4 px-4", @class, "cursor-help tooltip tooltip-left"]} data-tip={@explanation}>
      <.icon name={@icon} class="w-5 h-5" />
      <span class="text-sm font-semibold">{@label}</span>
    </div>
    """
  end
end
