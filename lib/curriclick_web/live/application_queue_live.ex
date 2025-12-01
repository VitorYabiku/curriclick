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

    {:ok, assign(socket, :applications, fetch_applications(user.id))}
  end

  def handle_info(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{}}, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :applications, fetch_applications(user.id))}
  end

  def handle_info({:application_updated, _id}, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :applications, fetch_applications(user.id))}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case Ash.get(JobApplication, id) do
      {:ok, app} ->
        Ash.destroy!(app)

        {:noreply,
         socket
         |> put_flash(:info, "Candidatura removida da fila.")
         |> assign(:applications, fetch_applications(socket.assigns.current_user.id))}

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
              {:noreply,
               socket
               |> put_flash(:info, "Candidatura enviada com sucesso!")
               |> assign(:applications, fetch_applications(socket.assigns.current_user.id))}

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

  defp fetch_applications(user_id) do
    JobApplication
    |> Ash.Query.filter(user_id == ^user_id and status == :draft)
    |> Ash.Query.load([:job_listing, :conversation, answers: [:requirement]])
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!()
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-4">
      <div class="flex items-center gap-4 mb-8">
        <h1 class="text-3xl font-bold">Fila de Candidaturas Pendentes</h1>
        <div class="badge badge-primary badge-lg">{length(@applications)}</div>
      </div>

      <%= if @applications == [] do %>
        <div class="text-center py-16 bg-base-200/50 rounded-xl border border-base-200 border-dashed">
          <div class="bg-base-200 p-4 rounded-full inline-block mb-4">
            <.icon name="hero-inbox-stack" class="w-8 h-8 opacity-50" />
          </div>
          <h3 class="text-lg font-bold">Sua fila está vazia</h3>
          <p class="text-base-content/70 mt-2 max-w-md mx-auto">
            Adicione vagas à fila através da Busca de Empregos para revisar as respostas aqui antes de enviar.
          </p>
          <div class="mt-6">
            <.link navigate={~p"/chat"} class="btn btn-primary">
              Buscar Vagas
            </.link>
          </div>
        </div>
      <% else %>
        <div class="space-y-6">
          <%= for app <- @applications do %>
            <div class="card bg-base-200 shadow-sm border border-base-200">
              <div class="card-body p-6">
                <div class="flex justify-between items-start">
                  <div>
                    <h2 class="card-title text-xl mb-1">{app.job_listing.title}</h2>
                    <p class="text-base-content/70 text-sm mb-4">
                      Criado em {Calendar.strftime(app.inserted_at, "%d/%m/%Y às %H:%M")}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <button
                      class="btn btn-sm btn-ghost text-error"
                      phx-click="remove"
                      phx-value-id={app.id}
                      data-confirm="Tem certeza que deseja remover esta candidatura da fila?"
                    >
                      <.icon name="hero-trash" class="w-4 h-4" /> Remover
                    </button>
                  </div>
                </div>

                <%= if app.answers == [] do %>
                  <div class="flex items-center gap-3 py-8 justify-center text-base-content/60">
                    <span class="loading loading-spinner loading-md"></span>
                    <span>Gerando respostas com IA...</span>
                  </div>
                <% else %>
                  <div class="divider my-2"></div>

                  <% issues =
                    Enum.filter(app.answers, fn a ->
                      a.confidence_score == :low or not is_nil(a.missing_info) or is_nil(a.answer)
                    end) %>

                  <%= if issues != [] do %>
                    <div class="alert alert-warning mb-6 shadow-sm">
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
                        "form-control p-5 rounded-xl transition-all shadow-sm bg-base-100",
                        if(answer.confidence_score == :low,
                          do: "border-2 border-error/50",
                          else:
                            if(answer.confidence_score == :medium,
                              do: "border-2 border-warning/50",
                              else: "border border-base-100"
                            )
                        )
                      ]}>
                        <div class="mb-3 flex justify-between items-start gap-4">
                          <span class="font-semibold text-lg leading-relaxed block text-base-content break-words">
                            {answer.requirement.question}
                          </span>
                          <.confidence_badge
                            score={answer.confidence_score}
                            explanation={answer.confidence_explanation}
                          />
                        </div>

                        <%= if answer.missing_info do %>
                          <div class="py-2 mb-2 w-full">
                            <div class="text-warning text-sm font-semibold flex items-start gap-2 w-full">
                              <.icon name="hero-exclamation-triangle" class="w-5 h-5 mt-0.5 flex-shrink-0" />
                              <span class="flex-1 min-w-0 whitespace-normal break-words">
                                <strong>Informação faltante:</strong> {answer.missing_info}
                              </span>
                            </div>
                          </div>
                        <% end %>

                        <textarea
                          class={["textarea textarea-bordered h-32 w-full text-base leading-relaxed focus:border-primary focus:ring-1 focus:ring-primary"]}
                          placeholder={
                            if is_nil(answer.answer),
                              do: "Informação ausente. Por favor, preencha manualmente ou forneça as informações faltantes."
                          }
                          phx-blur="update_answer"
                          phx-value-id={answer.id}
                        >{answer.answer}</textarea>


                        <%= if answer.confidence_explanation && answer.confidence_score != :high do %>
                          <div class="mt-2 text-sm opacity-90 flex gap-1 items-start w-full">
                            <.icon name="hero-information-circle" class="w-5 h-5 mt-0.5 flex-shrink-0" />
                            <span class="leading-relaxed flex-1 min-w-0 whitespace-normal break-words">{answer.confidence_explanation}</span>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <div class="card-actions justify-end mt-6 pt-4 border-t border-base-200">
                    <%
                      missing_questions =
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
                        end
                    %>
                    <div
                      class={if has_missing, do: "tooltip tooltip-left tooltip-error", else: ""}
                      data-tip={tooltip_msg}
                    >
                      <button
                        class="btn btn-primary"
                        disabled={has_missing}
                        phx-click="submit"
                        phx-value-id={app.id}
                      >
                        Confirmar a Candidatura <.icon name="hero-paper-airplane" class="w-4 h-4 ml-2" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
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
