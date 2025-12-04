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
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "job_applications")
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "job_applications:answer_updated")
      # Subscribe to JobApplication resource events
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "user_applications:create:#{user.id}")
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "user_applications:update:#{user.id}")
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "user_applications:destroy:#{user.id}")
    end

    applications = fetch_applications(user.id)

    socket =
      socket
      |> assign(:applications, applications)
      |> assign(
        :selected_application_id,
        if(applications != [], do: hd(applications).id, else: nil)
      )
      |> assign(:show_chat, false)
      |> assign(:chat_messages, [])
      |> assign(:chat_loading, false)

    {:ok, socket, layout: {CurriclickWeb.Layouts, :chat}}
  end

  def handle_info(%Phoenix.Socket.Broadcast{payload: %Ash.Notifier.Notification{}}, socket) do
    user = socket.assigns.current_user
    {:noreply, assign(socket, :applications, fetch_applications(user.id))}
  end

  def handle_info({:application_updated, id}, socket) do
    require Logger
    Logger.debug("Received application update for #{id}")
    user = socket.assigns.current_user
    applications = fetch_applications(user.id)

    # Preserve selection or default to first if previous selection is gone (rare for update)
    selected_id =
      socket.assigns.selected_application_id || if(applications != [], do: hd(applications).id)

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> assign(:selected_application_id, selected_id)}
  end

  def handle_info({:chat_delta, topic, deltas}, socket) do
    user_id = socket.assigns.current_user.id
    expected_topic = "job_application_queue_chat:#{user_id}"

    if topic == expected_topic do
      # Extract content from deltas
      content =
        Enum.reduce(deltas, "", fn delta, acc ->
          acc <> (delta.content || "")
        end)

      if content != "" do
        messages = socket.assigns.chat_messages

        updated_messages =
          case List.last(messages) do
            %{source: :assistant} = last ->
              List.replace_at(messages, -1, Map.update!(last, :text, &(&1 <> content)))

            _ ->
              messages ++ [%{source: :assistant, text: content}]
          end

        {:noreply, assign(socket, :chat_messages, updated_messages)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_info({:chat_complete, _}, socket) do
    {:noreply, assign(socket, :chat_loading, false)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    case Ash.get(JobApplication, id) do
      {:ok, app} ->
        Ash.destroy!(app)

        applications = fetch_applications(socket.assigns.current_user.id)
        new_selected_id = if applications != [], do: hd(applications).id, else: nil

         {:noreply,
          socket
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

  def handle_event("toggle_chat", _, socket) do
    user_id = socket.assigns.current_user.id
    topic = "job_application_queue_chat:#{user_id}"

    if socket.assigns.show_chat do
      # Closing chat
      Phoenix.PubSub.unsubscribe(Curriclick.PubSub, topic)
      {:noreply, assign(socket, :show_chat, false)}
    else
      # Opening chat
      Phoenix.PubSub.subscribe(Curriclick.PubSub, topic)

      {:noreply, assign(socket, :show_chat, true)}
    end
  end

  def handle_event("send_chat_message", %{"text" => text}, socket) do
    require Logger
    Logger.info("Sending chat message: #{text}")
    user_id = socket.assigns.current_user.id

    # Pass id: nil for queue chat

    messages = socket.assigns.chat_messages

    # Add user message immediately
    new_messages = messages ++ [%{source: :user, text: text}]

    # Prepare messages for the LLM (including the new one)
    action_messages =
      Enum.map(new_messages, fn msg ->
        %{"source" => to_string(msg.source), "text" => msg.text}
      end)

    pid = self()

    Task.start(fn ->
      try do
        # Call chat_with_assistant with id: nil (implicitly)
        Curriclick.Companies.JobApplication.chat_with_assistant!(user_id, action_messages)
        send(pid, {:chat_complete, nil})
      rescue
        e ->
          Logger.error("Chat failed: #{inspect(e)}")
          Logger.error(Exception.format(:error, e, __STACKTRACE__))
      end
    end)

    {:noreply,
     socket
     |> assign(:chat_messages, new_messages)
     |> assign(:chat_loading, true)}
  end

  defp fetch_applications(user_id) do
    answers_query =
      JobApplicationAnswer
      |> Ash.Query.sort(inserted_at: :asc)
      |> Ash.Query.load(:requirement)

    JobApplication
    |> Ash.Query.filter(user_id == ^user_id and status == :draft)
    |> Ash.Query.load([:conversation, answers: answers_query, job_listing: [:company]])
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
      Enum.count(answers, fn a -> a.confidence_score == :low end)

    medium_confidence_count =
      Enum.count(answers, fn a -> a.confidence_score == :medium end)

    %{
      missing_answers_count: length(missing_questions),
      missing_questions: missing_questions,
      missing_info_count: length(missing_infos),
      missing_infos: missing_infos,
      low_confidence_count: low_confidence_count,
      medium_confidence_count: medium_confidence_count
    }
  end

  def render(assigns) do
    ~H"""
    <% app =
      @selected_application_id && Enum.find(@applications, &(&1.id == @selected_application_id)) %>
    <div class="flex h-full overflow-hidden relative bg-base-100">
      <%= if @show_chat do %>
        <div class="h-full border-r border-base-300 bg-base-100 flex flex-col z-20 shadow-lg w-auto flex-1 max-w-[40%] xl:max-w-[35%]">
          <div class="flex flex-col h-full">
            <!-- Header -->
            <div class="flex items-center justify-between p-4 border-b border-base-300 bg-base-200/30">
              <h2 class="font-bold text-lg flex items-center gap-2">
                <.icon name="hero-sparkles" class="w-5 h-5" /> Assistente
              </h2>
              <button
                type="button"
                class="btn btn-ghost btn-sm btn-circle"
                phx-click="toggle_chat"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
            
    <!-- Messages -->
            <div
              class="flex-1 overflow-y-auto overflow-x-hidden p-4 flex flex-col items-center scroll-smooth"
              id="chat-messages"
              phx-hook="ChatScroll"
            >
              <%= if @chat_messages == [] do %>
                <div class="hero h-full flex items-center justify-center">
                  <div class="text-center px-6">
                    <div class="mb-4 inline-block p-3 bg-primary/10 rounded-full text-primary">
                      <.icon name="hero-chat-bubble-left-right" class="w-8 h-8" />
                    </div>
                    <h1 class="text-lg font-bold mb-4">
                      Como posso ajudar com suas candidaturas?
                    </h1>
                    <p class="text-sm text-base-content/70 font-medium leading-relaxed">
                      Pergunte sobre seus rascunhos ou forneça informações faltantes para eu gerar as respostas.
                    </p>
                  </div>
                </div>
              <% end %>

              <div class="w-full flex flex-col items-center gap-6">
                <%= for msg <- @chat_messages do %>
                  <div class={["w-full max-w-3xl", msg.source == :user && "flex justify-end"]}>
                    <%= if msg.source == :user do %>
                      <div class="chat-bubble chat-bubble-primary text-primary-content shadow-sm text-[15px] py-2.5 px-4 max-w-[85%]">
                        {to_markdown(msg.text)}
                      </div>
                    <% else %>
                      <div class="flex gap-4 w-full pr-4">
                        <div class="flex-1 min-w-0 py-1">
                          <div class="markdown-content prose prose-sm max-w-none">
                            {to_markdown(msg.text)}
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if @chat_loading do %>
                  <div class="w-full max-w-3xl">
                    <div class="flex gap-4 w-full pr-4">
                      <div class="flex-1 min-w-0 py-1">
                        <div class="flex items-center gap-2 text-base-content/50">
                          <span class="loading loading-dots loading-md"></span>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Input Area -->
            <div class="p-4 bg-gradient-to-t from-base-100 to-base-100/80 backdrop-blur-md z-10 w-full border-t border-base-300/50">
              <form phx-submit="send_chat_message" class="relative">
                <div class="flex w-full shadow-sm rounded-3xl border border-base-300 bg-base-100 p-1.5 focus-within:ring-2 focus-within:ring-primary/20 focus-within:border-primary/50 transition-all duration-200">
                  <input
                    type="text"
                    name="text"
                    placeholder="Digite sua mensagem..."
                    class="input input-ghost flex-1 focus:outline-none focus:bg-transparent h-auto py-2 text-sm border-none bg-transparent pl-4"
                    autocomplete="off"
                    required
                  />
                  <button
                    type="submit"
                    class="btn btn-primary btn-circle btn-sm h-9 w-9 self-center shadow-md hover:shadow-lg transition-all duration-200"
                    disabled={@chat_loading}
                  >
                    <%= if @chat_loading do %>
                      <span class="loading loading-spinner loading-xs"></span>
                    <% else %>
                      <.icon name="hero-arrow-up" class="w-4 h-4" />
                    <% end %>
                  </button>
                </div>
                <div class="text-center mt-2">
                  <span class="text-[10px] text-base-content/40">
                    A IA pode cometer erros.
                  </span>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
      
    <!-- Detailed View (Left/Middle) -->
      <div class="flex flex-col h-full overflow-hidden transition-all duration-300 bg-base-100 flex-1 min-w-0">
        
    <!-- Main Content Area -->
        <div class="flex-1 flex flex-col min-h-0 overflow-hidden">
          <%= if app do %>
            <div class="flex-1 overflow-y-auto scroll-smooth">
              <div class="max-w-4xl mx-auto min-h-full flex flex-col">
                <div class="p-4 md:p-8 flex-1">
                  <div class="flex justify-between items-start mb-6">
                    <div>
                      <h2 class="text-2xl font-bold mb-1">{app.job_listing.title}</h2>
                      <p class="text-base-content/70">
                        {app.job_listing.company.name}
                      </p>
                    </div>
                    <div class="flex items-center gap-2">
                      <p class="text-base-content/70 text-sm">
                        {Calendar.strftime(
                          app.inserted_at,
                          "%d/%m %H:%M"
                        )}
                      </p>
                    </div>
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
                          <div class="text-md">
                            <p>Encontramos {length(issues)} ponto(s) que precisam da sua revisão:</p>
                            <ul class="list-disc list-inside mt-1 opacity-80">
                              <%= for issue <- issues do %>
                                <li>
                                  {String.slice(issue.requirement.question, 0, 40)}{if String.length(
                                                                                         issue.requirement.question
                                                                                       ) > 40,
                                                                                       do: "..."}
                                  <%= if issue.confidence_score == :low do %>
                                    <span class="badge badge badge-error ml-1">
                                      Baixa confiança
                                    </span>
                                  <% end %>
                                  <%= if issue.confidence_score == :medium do %>
                                    <span class="badge badge badge-warning ml-1">
                                      Média confiança
                                    </span>
                                  <% end %>
                                  <%= if issue.missing_info do %>
                                    <span class="badge badge badge-warning ml-1">
                                      Informações Faltantes
                                    </span>
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
                            <div class="py-2 px-4 mb-4 text-sm">
                              <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-warning" />
                              <span>
                                Informação Faltante: <strong>{answer.missing_info}</strong>
                              </span>
                            </div>
                          <% end %>

                          <textarea
                            id={"answer-#{answer.id}"}
                            class={[
                              "textarea textarea-bordered h-32 w-full text-base leading-relaxed focus:border-primary focus:ring-1 focus:ring-primary bg-base-100"
                            ]}
                            placeholder={
                              if is_nil(answer.answer),
                                do:
                                  "Informação ausente. Por favor, preencha manualmente ou forneça as informações faltantes."
                            }
                            phx-blur="update_answer"
                            phx-value-id={answer.id}
                          >{answer.answer}</textarea>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%= if app.answers != [] do %>
              <div class="flex-none p-4 border-t border-base-200 bg-base-100 z-10">
                <div class="max-w-4xl mx-auto flex justify-between items-center">
                  <button
                    class="btn btn-ghost text-error"
                    phx-click="remove"
                    phx-value-id={app.id}
                    data-confirm="Tem certeza que deseja remover esta candidatura da fila?"
                  >
                    <.icon name="hero-trash" class="w-5 h-5" /> Remover da Fila
                  </button>

                  <% missing_questions =
                    app.answers
                    |> Enum.filter(fn a -> is_nil(a.answer) or String.trim(a.answer) == "" end)
                    |> Enum.map(fn a -> a.requirement.question end)

                  has_missing = missing_questions != []

                  tooltip_msg =
                    if has_missing do
                      "Perguntas Pendentes:\n" <>
                        Enum.map_join(missing_questions, "\n", fn q ->
                          "• " <>
                            String.slice(q, 0, 30) <> if(String.length(q) > 30, do: "...", else: "")
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
                      Confirmar a Candidatura
                      <.icon name="hero-paper-airplane" class="w-5 h-5 ml-2" />
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="flex-1 overflow-y-auto w-full">
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
            </div>
          <% end %>
        </div>
      </div>
      
    <!-- List (Right) -->
      <div class={[
        "h-full border-l border-base-300 bg-base-100 flex flex-col transition-all duration-300 w-auto flex-1",
        if(@show_chat, do: "max-w-[25%] xl:max-w-[20%]", else: "max-w-[40%] xl:max-w-[35%]")
      ]}>
        <!-- Application List -->
        <div class="flex flex-col h-full">
          <!-- Desktop Header -->
          <div class="flex items-center justify-between p-4 border-b border-base-300 bg-base-200/30 gap-2">
            <div class="flex items-center gap-2 min-w-0">
              <h2 class="font-bold text-lg truncate">
                {if @show_chat, do: "Fila", else: "Fila de Candidaturas"}
              </h2>
              <span class="badge badge-primary shrink-0">{length(@applications)}</span>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <button
                class={["btn btn-accent btn-sm text-accent-content", @show_chat && "btn-square"]}
                phx-click="toggle_chat"
              >
                <.icon name="hero-sparkles" class="w-4 h-4" />
                <%= if !@show_chat do %>
                  Assistente
                <% end %>
              </button>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto overflow-x-hidden p-4 bg-base-200/50">
            <div class="space-y-3">
              <%= for app <- @applications do %>
                <% stats = get_application_stats(app) %>
                <div
                  class={[
                    "card bg-base-100 shadow-sm border transition-all cursor-pointer hover:border-primary/50 hover:shadow-md group text-left",
                    @selected_application_id == app.id &&
                      "border-primary ring-1 ring-primary bg-primary/5"
                  ]}
                  phx-click="select_application"
                  phx-value-id={app.id}
                >
                  <div class="card-body p-4 gap-2">
                    <div>
                      <h3 class="font-bold text-base leading-tight">{app.job_listing.title}</h3>
                      <p class="text-sm text-base-content/60 mt-0.5">
                        {app.job_listing.company.name}
                      </p>
                    </div>
                    
    <!-- Stats -->
                    <div class="space-y-2 mt-2">
                      <%= if stats.missing_answers_count > 0 do %>
                        <div class="rounded-lg p-2">
                          <div class="text-error text-sm font-bold mb-1 flex items-center gap-1">
                            <.icon name="hero-pencil-square" class="w-3 h-3" />
                            {stats.missing_answers_count} Perguntas Pendentes
                          </div>
                          <ul class="list-disc list-inside text-xs opacity-80 space-y-0.5">
                            <%= for q <- stats.missing_questions do %>
                              <li class="truncate">{q}</li>
                            <% end %>
                          </ul>
                        </div>
                      <% end %>

                      <%= if stats.missing_info_count > 0 do %>
                        <div class="rounded-lg p-2">
                          <div class="text-warning text-sm font-bold mb-1 flex items-center gap-1">
                            <.icon name="hero-exclamation-triangle" class="w-3 h-3" />
                            {stats.missing_info_count} Informações Faltantes
                          </div>
                          <ul class="list-disc list-inside text-xs opacity-80 space-y-0.5">
                            <%= for info <- stats.missing_infos do %>
                              <li class="truncate cursor-help" title={info}>{info}</li>
                            <% end %>
                          </ul>
                        </div>
                      <% end %>

                      <%= if stats.low_confidence_count > 0 do %>
                        <div class="flex items-center gap-1 text-sm text-error font-medium">
                          {stats.low_confidence_count} baixa confiança
                        </div>
                      <% end %>

                      <%= if stats.medium_confidence_count > 0 do %>
                        <div class="flex items-center gap-1 text-sm text-warning font-medium">
                          {stats.medium_confidence_count} média confiança
                        </div>
                      <% end %>

                      <%= if stats.missing_answers_count == 0 && stats.missing_info_count == 0 && stats.low_confidence_count == 0 && stats.medium_confidence_count == 0 do %>
                        <div class="text-success text-sm font-bold flex items-center gap-1">
                          <.icon name="hero-check-circle" class="w-3 h-3" /> Pronto para enviar
                        </div>
                      <% end %>

                      <div class="hidden group-hover:flex justify-between items-center gap-2">
                        <button
                          class="btn btn-ghost text-error btn-sm"
                          phx-click="remove"
                          phx-value-id={app.id}
                          data-confirm="Tem certeza que deseja remover esta candidatura da fila?"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" /> Remover
                        </button>

                        <button
                          class="btn btn-primary btn-sm flex-1"
                          disabled={stats.missing_answers_count > 0}
                          phx-click="submit"
                          phx-value-id={app.id}
                        >
                          Confirmar a Candidatura
                          <.icon name="hero-paper-airplane" class="w-4 h-4 ml-2" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
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
    <div
      class={["badge badge-lg gap-2 py-4 px-4", @class, "cursor-help tooltip tooltip-left"]}
      data-tip={@explanation}
    >
      <.icon name={@icon} class="w-5 h-5" />
      <span class="text-sm font-semibold">{@label}</span>
    </div>
    """
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
