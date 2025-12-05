defmodule CurriclickWeb.UserProfileLive do
  @moduledoc """
  LiveView for editing the user's profile.
  """
  use CurriclickWeb, :live_view
  require Ash.Query
  alias Curriclick.Accounts

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Curriclick.PubSub, "user_profile_chat:#{socket.assigns.current_user.id}")
    end

    form =
      Accounts.form_to_update_profile(socket.assigns.current_user,
        actor: socket.assigns.current_user
      )
      |> to_form()

    remote_flags = remote_flags(socket.assigns.current_user.profile_remote_preference)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:remote_flags, remote_flags)
     |> assign(:show_chat, false)
     |> assign(:chat_messages, [])
     |> assign(:chat_loading, false), layout: {CurriclickWeb.Layouts, :chat}}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("toggle_chat", _, socket) do
    {:noreply, assign(socket, :show_chat, !socket.assigns.show_chat)}
  end

  def handle_event("send_chat_message", %{"text" => text}, socket) do
    require Logger
    Logger.info("Sending chat message: #{text}")
    user = socket.assigns.current_user
    user_id = user.id

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
        Curriclick.Accounts.User.chat_with_profile_assistant!(user_id, action_messages, actor: user)
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

  def handle_event("validate", %{"form" => params}, socket) do
    {normalized_params, remote_flags} =
      normalize_remote_params(params, socket.assigns.remote_flags)

    {:noreply,
     socket
     |> assign(:remote_flags, remote_flags)
     |> assign(
       :form,
       AshPhoenix.Form.validate(socket.assigns.form, normalized_params) |> to_form()
     )}
  end

  def handle_event("save", %{"form" => params}, socket) do
    {normalized_params, remote_flags} =
      normalize_remote_params(params, socket.assigns.remote_flags)

    case AshPhoenix.Form.submit(socket.assigns.form, params: normalized_params) do
      {:ok, user} ->
        form = Accounts.form_to_update_profile(user, actor: user) |> to_form()
        flags = remote_flags(user.profile_remote_preference)

        {:noreply,
         socket
         |> put_flash(:info, "Perfil salvo.")
         |> assign(:current_user, user)
         |> assign(:form, form)
         |> assign(:remote_flags, flags)}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:remote_flags, remote_flags)
         |> assign(:form, form)}
    end
  end

  def handle_info({:profile_updated, user_id}, socket) do
    if user_id == socket.assigns.current_user.id do
      user = Curriclick.Accounts.User |> Ash.get!(user_id, authorize?: false)

      form = Accounts.form_to_update_profile(user, actor: user) |> to_form()
      flags = remote_flags(user.profile_remote_preference)

      {:noreply,
       socket
       |> assign(:current_user, user)
       |> assign(:form, form)
       |> assign(:remote_flags, flags)
       |> put_flash(:info, "Perfil atualizado pela IA!")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:chat_delta, topic, deltas}, socket) do
    user_id = socket.assigns.current_user.id
    expected_topic = "user_profile_chat:#{user_id}"

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

  def render(assigns) do
    ~H"""
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
                      Olá, {@current_user.profile_first_name || "Visitante"}!
                    </h1>
                    <p class="text-sm text-base-content/70 font-medium leading-relaxed">
                      Estou aqui para ajudar a completar seu perfil e melhorar suas recomendações de vagas.
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

      <!-- Main Content (Right) -->
      <div class="flex flex-col h-full overflow-hidden transition-all duration-300 bg-base-100 flex-1 min-w-0">
        <div class="flex-1 flex flex-col min-h-0 overflow-hidden">
           <div class="flex-1 overflow-y-auto scroll-smooth">
              <div class="max-w-5xl mx-auto px-4 pb-12 pt-8 space-y-6 w-full">
                <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between bg-base-100/95 border border-base-100 rounded-xl px-4 py-3">
                  <div class="space-y-1">
                    <p class="text-xs md:text-sm uppercase tracking-wide text-base-content/70 font-semibold">
                      Perfil
                    </p>
                    <h1 class="text-3xl md:text-4xl font-bold text-base-content">
                      Preferências e instruções
                    </h1>
                    <p class="text-base md:text-lg text-base-content/80">
                      Guarde suas informações para personalizar buscas e respostas da IA.
                    </p>
                  </div>
                  <div class="flex gap-2">
                     <.link navigate={~p"/dashboard"} class="btn btn-outline btn-primary btn-sm md:btn-md">
                        Ver candidaturas
                     </.link>
                     <button
                        class={["btn btn-accent btn-sm md:btn-md", @show_chat && "btn-active"]}
                        phx-click="toggle_chat"
                     >
                        <.icon name="hero-sparkles" class="w-5 h-5" />
                        <%= if !@show_chat do %>
                          Assistente
                        <% else %>
                          Fechar Assistente
                        <% end %>
                     </button>
                  </div>
                </div>

                <div>
                  <.form
                    for={@form}
                    phx-change="validate"
                    phx-submit="save"
                    class="card bg-base-100/95 backdrop-blur-sm"
                  >
                    <div class="card-body grid grid-cols-1 gap-6">
                      <div class="rounded-xl bg-base-200 p-4 shadow-sm">
                        <div class="flex items-start justify-between gap-3 flex-wrap">
                          <div class="space-y-1">
                            <p class="text-lg font-semibold text-base-content/90">Informações pessoais</p>
                            <p class="text-base text-base-content/70">
                              Opcional, ajuda a personalizar suas recomendações.
                            </p>
                          </div>
                        </div>

                        <div class="divider my-2"></div>

                        <div class="mt-2 grid grid-cols-1 md:grid-cols-3 gap-4">
                          <.input
                            field={@form[:profile_first_name]}
                            label="Nome"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                            placeholder="Seu nome"
                          />

                          <.input
                            field={@form[:profile_last_name]}
                            label="Sobrenome"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                            placeholder="Seu sobrenome"
                          />

                          <.input
                            type="date"
                            field={@form[:profile_birth_date]}
                            label="Data de nascimento"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                          />

                          <.input
                            field={@form[:profile_phone]}
                            label="Telefone"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                            placeholder="(11) 91234-5678"
                          />

                          <.input
                            field={@form[:profile_location]}
                            label="Cidade / UF e CEP"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                            placeholder="São Paulo - SP, CEP 01234-567"
                          />

                          <.input
                            field={@form[:profile_cpf]}
                            label="CPF"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full input input-bordered input-lg text-lg"
                            placeholder="000.000.000-00"
                          />
                        </div>
                      </div>

                      <div class="space-y-3">
                        <div class="space-y-3 rounded-xl bg-base-200 p-4 shadow-sm">
                          <div class="space-y-1">
                            <p class="text-lg font-semibold text-base-content/90">
                              Experiência e habilidades
                            </p>
                            <p class="text-base text-base-content/70">
                              Conte à IA sobre sua área de atuação.
                            </p>
                          </div>

                          <div class="divider my-2"></div>

                          <div class="space-y-3">
                            <.input
                              field={@form[:profile_job_interests]}
                              label="Interesses profissionais / cargos"
                              label_class="text-base font-semibold text-base-content/80"
                              class="w-full input input-bordered input-lg text-lg"
                              placeholder="Ex.: Desenvolvedor backend Elixir, APIs, produtos B2B"
                            />

                            <.input
                              field={@form[:profile_skills]}
                              label="Principais habilidades"
                              label_class="text-base font-semibold text-base-content/80"
                              class="w-full input input-bordered input-lg text-lg"
                              placeholder="Ex.: Elixir, Phoenix, PostgreSQL, AWS, liderança técnica"
                            />

                            <.input
                              type="textarea"
                              field={@form[:profile_experience]}
                              rows="3"
                              label="Resumo da experiência"
                              label_class="text-base font-semibold text-base-content/80"
                              class="w-full textarea textarea-bordered textarea-lg text-lg leading-relaxed"
                              placeholder="Ex.: 4 anos desenvolvendo serviços web, liderança de squad por 1 ano"
                            />
                          </div>
                        </div>

                        <div class="space-y-3 rounded-xl bg-base-200 p-4 shadow-sm">
                          <div class="space-y-1">
                            <p class="text-lg font-semibold text-base-content/90">Educação</p>
                            <p class="text-base text-base-content/70">
                              Formações, certificações e cursos.
                            </p>
                          </div>

                          <div class="divider my-2"></div>

                          <.input
                            type="textarea"
                            field={@form[:profile_education]}
                            rows="3"
                            label="Educação e cursos"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full textarea textarea-bordered textarea-lg text-lg leading-relaxed"
                            placeholder="Graduação, certificações, cursos relevantes"
                          />
                        </div>

                        <div class="space-y-3 rounded-xl bg-base-200 p-4 shadow-sm">
                          <div class="space-y-1">
                            <p class="text-lg font-semibold text-base-content/90">Instruções para a IA</p>
                            <p class="text-base text-base-content/70">
                              Personalize como a IA deve responder.
                            </p>
                          </div>

                          <div class="divider my-2"></div>

                          <.input
                            type="textarea"
                            field={@form[:profile_custom_instructions]}
                            rows="5"
                            label="Instruções para a IA"
                            label_class="text-base font-semibold text-base-content/80"
                            class="w-full textarea textarea-bordered textarea-lg text-lg leading-relaxed"
                            placeholder="Tom de voz, preferências de vaga, o que evitar, como priorizar resultados"
                          />
                        </div>
                      </div>

                      <div class="space-y-3 rounded-xl bg-base-200 p-4 shadow-sm">
                        <div class="space-y-1">
                          <p class="text-lg font-semibold text-base-content/90">
                            Preferência de modalidade
                          </p>
                          <p class="text-base text-base-content/70">
                            Escolha as modalidades que você aceita.
                          </p>
                        </div>

                        <div class="divider my-2"></div>

                        <div class="grid grid-cols-1 gap-2 md:grid-cols-3">
                          <label class="flex w-full items-start justify-between gap-3 rounded-lg bg-base-100 px-3 py-2 shadow-sm">
                            <div class="min-w-0 space-y-1 break-words">
                              <p class="font-semibold text-base-content/90 text-base">Remoto</p>
                              <p class="text-base text-base-content/70">Trabalhar 100% à distância.</p>
                            </div>
                            <div class="join shrink-0">
                              <input
                                type="radio"
                                name="form[remote_remote]"
                                value="true"
                                checked={@remote_flags.remote}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  @remote_flags.remote && "btn-primary",
                                  !@remote_flags.remote && "btn-ghost"
                                ]}
                                aria-label="Sim"
                              />
                              <input
                                type="radio"
                                name="form[remote_remote]"
                                value="false"
                                checked={!@remote_flags.remote}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  !@remote_flags.remote && "btn-primary",
                                  @remote_flags.remote && "btn-ghost"
                                ]}
                                aria-label="Não"
                              />
                            </div>
                          </label>

                          <label class="flex w-full items-start justify-between gap-3 rounded-lg bg-base-100 px-3 py-2 shadow-sm">
                            <div class="min-w-0 space-y-1 break-words">
                              <p class="font-semibold text-base-content/90 text-base">Híbrido</p>
                              <p class="text-base text-base-content/70">
                                Modelo flexível entre escritório e remoto.
                              </p>
                            </div>
                            <div class="join shrink-0">
                              <input
                                type="radio"
                                name="form[remote_hybrid]"
                                value="true"
                                checked={@remote_flags.hybrid}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  @remote_flags.hybrid && "btn-primary",
                                  !@remote_flags.hybrid && "btn-ghost"
                                ]}
                                aria-label="Sim"
                              />
                              <input
                                type="radio"
                                name="form[remote_hybrid]"
                                value="false"
                                checked={!@remote_flags.hybrid}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  !@remote_flags.hybrid && "btn-primary",
                                  @remote_flags.hybrid && "btn-ghost"
                                ]}
                                aria-label="Não"
                              />
                            </div>
                          </label>

                          <label class="flex w-full items-start justify-between gap-3 rounded-lg bg-base-100 px-3 py-2 shadow-sm md:col-span-1">
                            <div class="min-w-0 space-y-1 break-words">
                              <p class="font-semibold text-base-content/90 text-base">Presencial</p>
                              <p class="text-base text-base-content/70">
                                Atuação no escritório / cliente.
                              </p>
                            </div>
                            <div class="join shrink-0">
                              <input
                                type="radio"
                                name="form[remote_on_site]"
                                value="true"
                                checked={@remote_flags.on_site}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  @remote_flags.on_site && "btn-primary",
                                  !@remote_flags.on_site && "btn-ghost"
                                ]}
                                aria-label="Sim"
                              />
                              <input
                                type="radio"
                                name="form[remote_on_site]"
                                value="false"
                                checked={!@remote_flags.on_site}
                                class={[
                                  "join-item btn btn-md md:btn-lg text-base",
                                  !@remote_flags.on_site && "btn-primary",
                                  @remote_flags.on_site && "btn-ghost"
                                ]}
                                aria-label="Não"
                              />
                            </div>
                          </label>
                        </div>
                      </div>
                    </div>

                    <div class="card-actions px-6 py-4 flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                      <div class="alert bg-base-200 text-base-content/80 shadow-sm w-full md:max-w-xl">
                        <.icon name="hero-information-circle" class="h-5 w-5 text-primary" />
                        <div class="space-y-1">
                          <p class="font-semibold text-base-content/90">Dicas</p>
                          <ul class="list-disc pl-4 space-y-1">
                            <li class="leading-relaxed">Campos em branco limpam instruções anteriores.</li>
                            <li class="leading-relaxed">
                              Alterações valem para futuras buscas e para o chat.
                            </li>
                          </ul>
                        </div>
                      </div>
                      <button type="submit" class="btn btn-primary btn-md">Salvar perfil</button>
                    </div>
                  </.form>
                </div>
              </div>
           </div>
        </div>
      </div>
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

  @spec normalize_remote_params(map(), map()) :: {map(), map()}
  defp normalize_remote_params(params, current_flags) do
    flags = %{
      remote: truthy?(Map.get(params, "remote_remote", current_flags.remote)),
      hybrid: truthy?(Map.get(params, "remote_hybrid", current_flags.hybrid)),
      on_site: truthy?(Map.get(params, "remote_on_site", current_flags.on_site))
    }

    preference = preference_from_flags(flags)

    normalized_params =
      params
      |> Map.put("profile_remote_preference", Atom.to_string(preference))
      |> Map.drop(["remote_remote", "remote_hybrid", "remote_on_site"])

    {normalized_params, flags}
  end

  @spec truthy?(any()) :: boolean()
  defp truthy?(value) do
    case value do
      true -> true
      "true" -> true
      "on" -> true
      "1" -> true
      _ -> false
    end
  end

  @spec preference_from_flags(map()) :: atom()
  defp preference_from_flags(%{remote: true, hybrid: true, on_site: true}), do: :no_preference
  defp preference_from_flags(%{remote: true, hybrid: true, on_site: false}), do: :remote_friendly
  defp preference_from_flags(%{remote: true, hybrid: false, on_site: false}), do: :remote_only
  defp preference_from_flags(%{remote: false, hybrid: true, on_site: false}), do: :hybrid
  defp preference_from_flags(%{remote: false, hybrid: false, on_site: true}), do: :on_site
  defp preference_from_flags(%{remote: true, hybrid: false, on_site: true}), do: :hybrid
  defp preference_from_flags(%{remote: false, hybrid: true, on_site: true}), do: :hybrid
  defp preference_from_flags(_), do: :no_preference

  @spec remote_flags(atom() | nil) :: map()
  defp remote_flags(current_value) do
    case current_value do
      :remote_only -> %{remote: true, hybrid: false, on_site: false}
      :remote_friendly -> %{remote: true, hybrid: true, on_site: false}
      :hybrid -> %{remote: false, hybrid: true, on_site: true}
      :on_site -> %{remote: false, hybrid: false, on_site: true}
      _ -> %{remote: true, hybrid: true, on_site: true}
    end
  end
end
