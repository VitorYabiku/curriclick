defmodule CurriclickWeb.ChatLive do
  use Elixir.CurriclickWeb, :live_view
  require Ash.Query
  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  @max_conversation_title_length 25

  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open h-full bg-base-100">
      <input id="ash-ai-drawer" type="checkbox" class="drawer-toggle" />
      
      <!-- Main Content Area (Chat + Jobs Panel) -->
      <div class="drawer-content flex h-full overflow-hidden relative">
        <!-- Job Details Section (Replaces Chat) -->
        <div class={[
          "flex-col h-full overflow-hidden transition-all duration-300 bg-base-100",
          @expanded_job_id && "flex",
          !@expanded_job_id && "hidden",
          @show_jobs_panel && @job_cards != [] && "flex-1 lg:max-w-[60%] xl:max-w-[65%]",
          !(@show_jobs_panel && @job_cards != []) && "flex-1"
        ]}>
            <!-- Header -->
            <div class="navbar bg-base-100 w-full border-b border-base-200 min-h-12 flex-none shadow-sm z-10">
              <div class="flex-none">
                <button 
                  type="button" 
                  class="btn btn-ghost btn-sm gap-2" 
                  phx-click="collapse_job_detail"
                >
                  <.icon name="hero-arrow-left" class="w-5 h-5" />
                  <span class="font-normal">Voltar ao Chat</span>
                </button>
              </div>
              <div class="flex-1"></div>
              <%= if @job_cards != [] do %>
                <div class="flex-none lg:hidden">
                  <button
                    type="button"
                    class="btn btn-square btn-ghost btn-sm"
                    phx-click="toggle_jobs_panel"
                    aria-label={if @show_jobs_panel, do: "Esconder vagas", else: "Mostrar vagas"}
                  >
                    <.icon name="hero-briefcase" class="w-5 h-5" />
                    <span class="badge badge-primary badge-xs absolute -top-1 -right-1">
                      {length(@job_cards)}
                    </span>
                  </button>
                </div>
              <% end %>
            </div>

            <!-- Job Details Content -->
            <div class="flex-1 overflow-y-auto p-4 lg:p-8 scroll-smooth">
              <% expanded_job = Enum.find(@job_cards, & &1.job_id == @expanded_job_id) %>
              <%= if expanded_job do %>
                <div class="max-w-4xl mx-auto space-y-6">
                  <!-- Main Card -->
                  <div class="card bg-base-100">
                    <div class="space-y-6">
                      <!-- Header -->
                      <div class="flex flex-col md:flex-row md:items-start justify-between gap-4 border-b border-base-200 pb-6">
                        <div class="flex-1">
                          <h1 class="font-bold text-2xl md:text-3xl mb-2">{expanded_job.title}</h1>
                          <div class="flex items-center gap-2 text-lg text-base-content/80 font-medium">
                            <.icon name="hero-building-office-2" class="w-5 h-5" />
                            {expanded_job.company_name}
                          </div>
                          <%= if expanded_job.location do %>
                            <p class="text-base text-base-content/60 flex items-center gap-2 mt-2">
                              <.icon name="hero-map-pin" class="w-4 h-4" />
                              {expanded_job.location}
                            </p>
                          <% end %>
                        </div>
                        <div class="flex flex-col items-end gap-3">
                          <.match_quality_badge quality={expanded_job.match_quality.score} explanation={expanded_job.match_quality.explanation} />
                          <% is_applied = MapSet.member?(@applied_job_ids, expanded_job.job_id) %>
                          <% is_failed = MapSet.member?(@failed_job_ids, expanded_job.job_id) %>
                          
                          <%= if is_applied do %>
                            <button
                              type="button"
                              disabled
                              class="btn btn-disabled rounded-xl shadow-none w-full md:w-auto bg-base-200 text-base-content/50 border-base-300"
                            >
                              <.icon name="hero-check-circle" class="w-4 h-4" />
                              Já candidatado
                            </button>
                          <% else %>
                            <button
                              type="button"
                              class={["btn rounded-xl shadow-md w-full md:w-auto", is_failed && "btn-error", !is_failed && "btn-primary"]}
                              phx-click="apply_to_job"
                              phx-value-job_id={expanded_job.job_id}
                            >
                              <%= if is_failed do %>
                                <.icon name="hero-arrow-path" class="w-4 h-4" />
                                Tentar novamente
                              <% else %>
                                <.icon name="hero-paper-airplane" class="w-4 h-4" />
                                Candidatar-se
                              <% end %>
                            </button>
                            <%= if is_failed do %>
                              <span class="text-xs text-error font-medium">Falha ao enviar. Tente novamente.</span>
                            <% end %>
                          <% end %>
                        </div>
                      </div>
                      
                      <!-- Meta info -->
                      <div class="flex flex-wrap gap-3">
                        <%= if expanded_job.keywords && expanded_job.keywords != [] do %>
                          <div class="w-full flex flex-wrap gap-1 mb-2">
                             <%= for keyword <- expanded_job.keywords do %>
                               <div class="tooltip" data-tip={keyword.explanation}>
                                 <span class="badge badge-ghost badge-sm cursor-help">{keyword.term}</span>
                               </div>
                             <% end %>
                          </div>
                        <% end %>

                        <%= if expanded_job.remote_allowed do %>
                          <span class="badge badge-lg badge-outline gap-2 p-3">
                            <.icon name="hero-home" class="w-4 h-4" /> Remoto
                          </span>
                        <% end %>
                        <%= if expanded_job.work_type do %>
                          <span class="badge badge-lg badge-outline p-3">
                            {format_work_type(expanded_job.work_type)}
                          </span>
                        <% end %>
                        <%= if expanded_job.salary_range do %>
                          <span class="badge badge-lg badge-outline gap-2 p-3">
                            <.icon name="hero-currency-dollar" class="w-4 h-4" />
                            {expanded_job.salary_range}
                          </span>
                        <% end %>
                      </div>
                      
                      <!-- Summary -->
                      <div class="bg-primary/5 rounded-2xl p-6 border border-primary/10">
                        <h3 class="font-semibold text-primary mb-2">Resumo</h3>
                        <p class="text-base leading-relaxed">{expanded_job.summary}</p>
                      </div>
                      
                      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <!-- Pros -->
                        <%= if expanded_job.pros && expanded_job.pros != [] do %>
                          <div class="bg-base-200/30 rounded-2xl p-6">
                            <h4 class="font-semibold text-success flex items-center gap-2 mb-4">
                              <.icon name="hero-check-circle" class="w-5 h-5" /> Pontos Positivos
                            </h4>
                            <ul class="space-y-3">
                              <%= for pro <- expanded_job.pros do %>
                                <li class="text-base-content/80 flex items-start gap-3">
                                  <span class="text-success mt-1">•</span>
                                  <span>{pro}</span>
                                </li>
                              <% end %>
                            </ul>
                          </div>
                        <% end %>
                        
                        <!-- Cons -->
                        <%= if expanded_job.cons && expanded_job.cons != [] do %>
                          <div class="bg-base-200/30 rounded-2xl p-6">
                            <h4 class="font-semibold text-warning flex items-center gap-2 mb-4">
                              <.icon name="hero-exclamation-triangle" class="w-5 h-5" /> Pontos de Atenção
                            </h4>
                            <ul class="space-y-3">
                              <%= for con <- expanded_job.cons do %>
                                <li class="text-base-content/80 flex items-start gap-3">
                                  <span class="text-warning mt-1">•</span>
                                  <span>{con}</span>
                                </li>
                              <% end %>
                            </ul>
                          </div>
                        <% end %>
                      </div>
                      
                      <!-- Missing Info -->
                      <%= if expanded_job.missing_info do %>
                        <div class="alert alert-info bg-info/10 border-info/20 text-xs">
                          <.icon name="hero-information-circle" class="w-5 h-5" />
                          <span>{expanded_job.missing_info}</span>
                        </div>
                      <% end %>
                      
                      <!-- Full Description -->
                      <%= if expanded_job.description do %>
                        <div class="border-t border-base-200 pt-8 mt-8">
                          <h4 class="font-bold text-lg mb-4">Descrição Completa da Vaga</h4>
                          <div class="prose prose-base max-w-none text-base-content/80">
                            {expanded_job.description}
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          <!-- Chat Section -->
          <div class={[
            "flex-col h-full overflow-hidden transition-all duration-300",
            !@expanded_job_id && "flex",
            @expanded_job_id && "hidden",
            @show_jobs_panel && @job_cards != [] && "flex-1 lg:max-w-[60%] xl:max-w-[65%]",
            !(@show_jobs_panel && @job_cards != []) && "flex-1"
          ]}>
          <!-- Mobile Header -->
          <div class="navbar bg-base-100 w-full md:hidden border-b border-base-200 min-h-12">
            <div class="flex-none">
              <label
                for="ash-ai-drawer"
                aria-label="open sidebar"
                class="btn btn-square btn-ghost btn-sm"
              >
                <.icon name="hero-bars-3" class="w-5 h-5" />
              </label>
            </div>
            <div class="flex-1 px-2 mx-2 text-sm font-semibold">Curriclick IA</div>
            <%= if @job_cards != [] do %>
              <div class="flex-none lg:hidden">
                <button
                  type="button"
                  class="btn btn-square btn-ghost btn-sm"
                  phx-click="toggle_jobs_panel"
                  aria-label={if @show_jobs_panel, do: "Esconder vagas", else: "Mostrar vagas"}
                >
                  <.icon name="hero-briefcase" class="w-5 h-5" />
                  <span class="badge badge-primary badge-xs absolute -top-1 -right-1">
                    {length(@job_cards)}
                  </span>
                </button>
              </div>
            <% end %>
          </div>
          
      <!-- Messages Area -->
          <div
            class="flex-1 overflow-y-auto p-4 flex flex-col items-center scroll-smooth"
            id="message-container"
            phx-hook="ChatScroll"
          >
            <div id="message-stream" phx-update="stream" class="w-full flex flex-col items-center">
              <%= for {id, message} <- @streams.messages do %>
                <div
                  id={id}
                  class={[
                    "w-full max-w-3xl mb-8",
                    message.source == :user && "flex justify-end"
                  ]}
                >
                  <%= if message.source == :user do %>
                    <div class="chat-bubble chat-bubble-primary text-primary-content shadow-sm text-[15px] py-2.5 px-4 max-w-[85%]">
                      {to_markdown(message.text)}
                    </div>
                  <% else %>
                    <div class="flex gap-4 w-full pr-4">
                      <div class="flex-1 min-w-0 py-1">
                        <%= if message.tool_calls && message.tool_calls != [] do %>
                          <div class="flex flex-col gap-2 mb-4">
                            <%= for tool_call <- message.tool_calls do %>
                              <details
                                id={"tool-#{tool_call["call_id"]}"}
                                class="collapse collapse-arrow bg-base-200 border border-base-300 rounded-lg"
                              >
                                <summary class="collapse-title text-sm font-medium min-h-0 py-2 px-4">
                                  <div class="flex items-center gap-2">
                                    <.icon name="hero-wrench-screwdriver" class="w-4 h-4" />
                                    Usando ferramenta:
                                    <span class="font-mono text-xs bg-base-300 px-1 rounded">
                                      {tool_call["name"]}
                                    </span>
                                  </div>
                                </summary>
                                <div class="collapse-content text-xs">
                                  <div class="mt-2">
                                    <div class="font-bold opacity-70 mb-1">Argumentos:</div>
                                    <pre class="whitespace-pre-wrap overflow-x-auto bg-base-300 p-2 rounded border border-base-content/10"><%= if is_binary(tool_call["arguments"]), do: tool_call["arguments"], else: inspect(tool_call["arguments"]) %></pre>
                                  </div>

                                  <% result =
                                    if message.tool_results,
                                      do:
                                        Enum.find(message.tool_results, fn r ->
                                          r["tool_call_id"] == tool_call["call_id"]
                                        end) %>
                                  <%= if result do %>
                                    <div class="mt-2">
                                      <div class="font-bold opacity-70 mb-1">Resultado:</div>
                                      <pre class="whitespace-pre-wrap overflow-x-auto bg-base-300 p-2 rounded border border-base-content/10"><%= result["content"] %></pre>
                                    </div>
                                  <% else %>
                                    <div class="mt-2 flex items-center gap-2 text-info">
                                      <span class="loading loading-spinner loading-xs"></span>
                                      <span>Executando...</span>
                                    </div>
                                  <% end %>
                                </div>
                              </details>
                            <% end %>
                          </div>
                        <% end %>

                        <div class="markdown-content">
                          {to_markdown(message.text)}
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%= if @loading_response do %>
              <div class="w-full max-w-3xl mb-8">
                <div class="flex gap-4 w-full pr-4">
                  <div class="flex-1 min-w-0 py-1">
                    <div class="flex items-center gap-2 text-base-content/50">
                      <span class="loading loading-dots loading-xl"></span>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>

            <%= if !@conversation do %>
              <div class="hero h-full min-h-[40vh] flex items-center justify-center pb-10">
                <div class="hero-content text-center">
                  <div class="max-w-md">
                    <div class="mb-6 inline-block p-4 bg-primary/10 rounded-full text-primary">
                      <.icon name="hero-chat-bubble-left-right" class="w-10 h-10" />
                    </div>
                    <h1 class="text-2xl font-bold">Como posso ajudar você hoje?</h1>
                    <p class="py-4 text-sm text-base-content/70">
                      Pergunte-me qualquer coisa sobre seu currículo, busca de emprego ou conselhos de carreira.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
      <!-- Input Area -->
          <div class="p-4 bg-gradient-to-t from-base-100 to-base-100/80 backdrop-blur-md z-10 w-full border-t-2 border-base-300 shadow-[0_-4px_20px_-4px_rgba(0,0,0,0.1)]">
            <.form
              :let={form}
              for={@message_form}
              phx-change="validate_message"
              phx-submit="send_message"
              class="relative max-w-3xl mx-auto"
            >
              <div class="flex w-full shadow-xl rounded-3xl border-2 border-base-300 bg-base-100 p-2 focus-within:ring-4 focus-within:ring-primary/30 focus-within:border-primary/50 transition-all duration-200 hover:shadow-2xl">
                <input
                  name={form[:text].name}
                  value={form[:text].value}
                  type="text"
                  phx-mounted={JS.focus()}
                  placeholder="Mensagem para Curriclick IA..."
                  class="input input-ghost flex-1 focus:outline-none focus:bg-transparent h-auto py-3 text-base border-none bg-transparent pl-4"
                  autocomplete="off"
                />

                <button
                  type="submit"
                  class="btn btn-primary btn-circle h-10 w-10 self-center shadow-lg hover:shadow-xl transition-all duration-200"
                  disabled={!form[:text].value || form[:text].value == ""}
                >
                  <.icon name="hero-arrow-up" class="w-5 h-5" />
                </button>
              </div>
              <div class="text-center mt-2">
                <span class="text-[10px] text-base-content/40">
                  A IA pode cometer erros. Verifique informações importantes.
                </span>
              </div>
            </.form>
          </div>
        </div>
        
      <!-- Job Cards Panel -->
        <%= if @job_cards != [] do %>
          <div class={[
            "h-full border-l border-base-300 bg-base-100 flex flex-col transition-all duration-300",
            "fixed inset-y-0 right-0 z-30 w-full sm:w-[420px] lg:relative lg:w-auto lg:flex-1 lg:max-w-[40%] xl:max-w-[35%]",
            @show_jobs_panel && "translate-x-0",
            !@show_jobs_panel && "translate-x-full lg:translate-x-0 lg:hidden"
          ]}>
            <!-- Panel Header -->
            <div class="flex flex-col border-b border-base-300 bg-base-100 shadow-sm">
              <div class="flex items-center justify-between p-4 pb-2">
                <div class="flex items-center gap-3">
                  <div class="p-2 bg-primary/10 rounded-xl">
                    <.icon name="hero-briefcase" class="w-5 h-5 text-primary" />
                  </div>
                  <div>
                    <h2 class="font-bold text-base">Vagas Encontradas</h2>
                    <p class="text-xs text-base-content/60">{length(@job_cards)} resultados</p>
                  </div>
                </div>
                <button
                  type="button"
                  class="btn btn-ghost btn-sm btn-circle lg:hidden"
                  phx-click="toggle_jobs_panel"
                  aria-label="Fechar painel"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
              
              <div class="flex items-center justify-between px-4 pb-3 gap-2">
                  <div class="flex items-center gap-2">
                    <label class="cursor-pointer flex items-center gap-2 text-xs font-medium text-base-content/70 hover:text-base-content select-none">
                      <input 
                        type="checkbox" 
                        class="checkbox checkbox-xs checkbox-primary rounded"
                        checked={@job_cards != [] && MapSet.size(@selected_job_ids) == length(Enum.reject(@job_cards, &MapSet.member?(@applied_job_ids, &1.job_id)))}
                        phx-click="toggle_select_all" 
                      />
                      Selecionar todos
                    </label>
                  </div>
                  
                  <div class="dropdown dropdown-end">
                    <div tabindex="0" role="button" class="btn btn-ghost btn-xs gap-1 font-normal text-base-content/70">
                      <.icon name="hero-arrows-up-down" class="w-3 h-3" />
                      {if @sort_by == :match, do: "Relevância", else: "Probabilidade"}
                    </div>
                    <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-40 border border-base-200 text-xs">
                      <li><button type="button" class={@sort_by == :match && "active"} phx-click="sort" phx-value-sort_by="match">Relevância</button></li>
                      <li><button type="button" class={@sort_by == :probability && "active"} phx-click="sort" phx-value-sort_by="probability">Probabilidade</button></li>
                    </ul>
                  </div>
              </div>
            </div>
            
        <!-- Panel Content -->
            <div class="flex-1 overflow-y-auto p-4">
              <!-- Job Cards List -->
              <div class="space-y-3" id="job-cards-stream" phx-update="stream">
              <%= for {dom_id, job_card} <- @streams.job_cards do %>
                <% is_applied = MapSet.member?(@applied_job_ids, job_card.job_id) %>
                <% is_failed = MapSet.member?(@failed_job_ids, job_card.job_id) %>
                <div
                  id={dom_id}
                  class={[
                    "card shadow-md border rounded-2xl transition-all duration-200 hover:shadow-lg hover:border-primary/30 cursor-pointer group",
                    @expanded_job_id == job_card.job_id && "bg-gradient-to-r from-primary/15 to-base-100 border-primary shadow-lg shadow-primary/10 ring-2 ring-primary",
                    @expanded_job_id != job_card.job_id && "bg-base-100 border-base-300",
                    is_applied && "opacity-75 bg-base-200/50"
                  ]}
                  phx-click="expand_job_detail"
                  phx-value-job_id={job_card.job_id}
                  onclick={"if (window.innerWidth < 1024) { window.dispatchEvent(new CustomEvent('close_panel')); }"}
                >
                  <div class="card-body p-4 gap-3">
                    <!-- Header with checkbox -->
                    <div
                      class={["flex items-start gap-3 -m-2 p-2 rounded-xl transition-colors", !is_applied && "cursor-pointer hover:bg-base-200/50"]}
                      phx-click={if !is_applied, do: "toggle_job_selection"}
                      phx-value-job_id={job_card.job_id}
                      phx-click-stop
                    >
                      <label class={["cursor-pointer flex items-center", is_applied && "cursor-not-allowed opacity-50"]}>
                        <input
                          type="checkbox"
                          class="checkbox checkbox-primary checkbox-sm rounded-lg pointer-events-none"
                          checked={MapSet.member?(@selected_job_ids, job_card.job_id)}
                          disabled={is_applied}
                        />
                      </label>
                      <div class="flex-1 min-w-0">
                        <h3 class="font-bold text-sm leading-tight">{job_card.title}</h3>
                        <p class="text-xs text-base-content/60 mt-0.5">{job_card.company_name}</p>
                        <%= if job_card.location do %>
                          <p class="text-xs text-base-content/50 flex items-center gap-1 mt-1">
                            <.icon name="hero-map-pin" class="w-3 h-3" />
                            {job_card.location}
                          </p>
                        <% end %>
                    </div>
                      <.match_quality_badge quality={job_card.match_quality.score} explanation={job_card.match_quality.explanation} />
                    </div>
                    
                    <!-- Summary -->
                    <p class="text-xs text-base-content/70 line-clamp-2">
                      {job_card.summary}
                    </p>

                    <%= if job_card.keywords && job_card.keywords != [] do %>
                      <div class="flex flex-wrap gap-1 mt-2 mb-1">
                         <%= for keyword <- Enum.take(job_card.keywords, 3) do %>
                           <div class="tooltip" data-tip={keyword.explanation}>
                             <span class="badge badge-ghost badge-xs text-base-content/60 cursor-help">{keyword.term}</span>
                           </div>
                         <% end %>
                         <%= if length(job_card.keywords) > 3 do %>
                           <span class="badge badge-ghost badge-xs text-base-content/60">+{length(job_card.keywords) - 3}</span>
                         <% end %>
                      </div>
                    <% end %>
                    
                    <!-- Quick info badges -->
                    <div class="flex flex-wrap gap-1.5">
                      <%= if job_card.remote_allowed do %>
                        <span class="badge badge-ghost badge-xs gap-1">
                          <.icon name="hero-home" class="w-2.5 h-2.5" /> Remoto
                        </span>
                      <% end %>
                      <%= if job_card.salary_range do %>
                        <span class="badge badge-ghost badge-xs">{job_card.salary_range}</span>
                      <% end %>
                    </div>
                    
                    <!-- Actions -->
                    <div class="flex gap-2 mt-1">
                      <%= if is_applied do %>
                        <button
                          type="button"
                          disabled
                          class="btn btn-disabled btn-xs flex-1 rounded-lg bg-base-200 text-base-content/50 border-base-300"
                        >
                          <.icon name="hero-check-circle" class="w-3.5 h-3.5" />
                          Candidatado
                        </button>
                      <% else %>
                        <button
                          type="button"
                          class={["btn btn-xs flex-1 rounded-lg", is_failed && "btn-error", !is_failed && "btn-primary"]}
                          phx-click="apply_to_job"
                          phx-value-job_id={job_card.job_id}
                          phx-click-stop
                        >
                          <%= if is_failed do %>
                             <.icon name="hero-arrow-path" class="w-3.5 h-3.5" />
                             Tentar novamente
                          <% else %>
                             <.icon name="hero-paper-airplane" class="w-3.5 h-3.5" />
                             Candidatar
                          <% end %>
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
                </div>
            </div>
            
        <!-- Panel Footer (batch selection actions) -->
            <%= if MapSet.size(@selected_job_ids) > 0 do %>
              <div class="p-4 border-t-2 border-base-300 bg-base-100 shadow-inner">
                <button
                  type="button"
                  class="btn btn-primary btn-block rounded-xl shadow-lg"
                  phx-click="apply_to_selected"
                >
                  <.icon name="hero-paper-airplane" class="w-4 h-4" />
                  Candidatar-se <%= if MapSet.size(@selected_job_ids) == 1, do: "à vaga selecionada", else: "às #{MapSet.size(@selected_job_ids)} vagas selecionadas" %>
                </button>
              </div>
            <% end %>
          </div>
          
      <!-- Mobile overlay when panel is open -->
          <%= if @show_jobs_panel do %>
            <div
              class="fixed inset-0 bg-black/50 z-20 lg:hidden"
              phx-click="toggle_jobs_panel"
              phx-window-close_panel="toggle_jobs_panel"
            >
            </div>
          <% end %>
        <% end %>
      </div>
      
    <!-- Sidebar -->
      <div class="drawer-side h-full absolute md:relative z-20">
        <label for="ash-ai-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <div class="menu p-4 w-72 h-full bg-base-200/50 border-r-2 border-base-300 text-base-content flex flex-col shadow-lg">
          <!-- New Chat Button -->
          <div class="mb-5">
            <.link
              navigate={~p"/chat"}
              class="btn btn-ghost btn-block relative normal-case font-medium shadow-sm border border-base-300 bg-primary hover:bg-base-200 hover:shadow transition-all duration-200"
            >
              <.icon name="hero-plus" class="w-5 h-5 absolute left-4 top-1/2 -translate-y-1/2" />
              Novo chat
            </.link>
          </div>

          <div class="flex-1 overflow-y-auto -mx-2 px-2">
            <div class="divider text-[10px] font-bold text-base-content/50 uppercase tracking-wider mx-1 my-2">
              Chats Anteriores
            </div>
            <ul class="space-y-1" phx-update="stream" id="conversations-list">
              <%= for {id, conversation} <- @streams.conversations do %>
                <li id={id} class="group relative">
                  <.link
                    navigate={~p"/chat/#{conversation.id}"}
                    phx-click="select_conversation"
                    phx-value-id={conversation.id}
                    class={[
                      "group flex items-center gap-2 rounded-xl px-3 py-2.5 text-sm transition-all hover:bg-base-100 hover:shadow-md pr-10",
                      if(@conversation && @conversation.id == conversation.id,
                        do: "bg-base-100 font-medium text-base-content shadow-md border border-base-300",
                        else: "text-base-content/70"
                      )
                    ]}
                  >
                    <span
                      class="truncate flex-1"
                      title={conversation_title_tooltip(conversation.title)}
                    >
                      {build_conversation_title_string(conversation.title)}
                    </span>
                  </.link>
                  <button
                    type="button"
                    class="absolute right-2 top-1/2 -translate-y-1/2 btn btn-ghost btn-circle btn-xs text-error opacity-0 group-hover:opacity-100 focus:opacity-100 focus-visible:opacity-100 transition-opacity"
                    phx-click="delete_conversation"
                    phx-value-id={conversation.id}
                    phx-click-stop
                    data-confirm="Tem certeza que deseja excluir esta conversa? Essa ação não pode ser desfeita."
                    aria-label="Excluir conversa"
                  >
                    <.icon name="hero-trash" class="w-3.5 h-3.5" />
                  </button>
                </li>
              <% end %>
            </ul>
          </div>
          
    <!-- Footer -->
          <div class="mt-auto pt-4 border-t-2 border-base-300">
            <!-- User info or settings could go here -->
          </div>
        </div>
      </div>
    </div>
    """
  end

  def conversation_title_tooltip(title) do
    if title && String.length(title) > @max_conversation_title_length do
      title
    else
      nil
    end
  end

  def build_conversation_title_string(title) do
    cond do
      title == nil ->
        "Conversa sem título"

      is_binary(title) && String.length(title) > @max_conversation_title_length ->
        String.slice(title, 0, @max_conversation_title_length) <> "..."

      is_binary(title) && String.length(title) <= @max_conversation_title_length ->
        title
    end
  end

  # Match quality badge component
  attr :quality, :atom, required: true
  attr :explanation, :string, default: nil

  def match_quality_badge(assigns) do
    {label, badge_class} =
      case assigns.quality do
        :good_match -> {"Bom", "badge-info"}
        :moderate_match -> {"Moderado", "badge-warning"}
        :bad_match -> {"Baixo", "badge-ghost"}
        _ -> {"--", "badge-ghost"}
      end

    assigns = assign(assigns, label: label, badge_class: badge_class)

    ~H"""
    <%= if @explanation do %>
      <div class="tooltip" data-tip={@explanation}>
        <span class={["badge badge-sm font-medium cursor-help", @badge_class]}>
          {@label}
        </span>
      </div>
    <% else %>
      <span class={["badge badge-sm font-medium", @badge_class]}>
        {@label}
      </span>
    <% end %>
    """
  end

  defp format_work_type(work_type) do
    case to_string(work_type) do
      "FULL_TIME" -> "Tempo integral"
      "PART_TIME" -> "Meio período"
      "CONTRACT" -> "Contrato"
      "INTERNSHIP" -> "Estágio"
      "TEMPORARY" -> "Temporário"
      other -> other
    end
  end


  defp create_job_application(user, job_card, search_query, conversation_id) do
    Curriclick.Companies.JobApplication
    |> Ash.Changeset.for_create(:create, %{
      user_id: user.id,
      job_listing_id: job_card.job_id,
      conversation_id: conversation_id,
      search_query: search_query,
      summary: job_card.summary,
      pros: job_card.pros,
      cons: job_card.cons,
      keywords:
        Enum.map(job_card.keywords || [], fn
          %_{} = keyword ->
            Map.from_struct(keyword)
            |> Map.drop([
              :__meta__,
              :__metadata__,
              :__order__,
              :__lateral_join_source__,
              :aggregates,
              :calculations
            ])

          other ->
            other
        end),
      work_type_score: sanitize_score(job_card.work_type_score),
      location_score: sanitize_score(job_card.location_score),
      salary_score: sanitize_score(job_card.salary_score),
      remote_score: sanitize_score(job_card.remote_score),
      skills_score: sanitize_score(job_card.skills_score),
      match_quality: sanitize_score(job_card.match_quality),
      hiring_probability: sanitize_score(job_card.hiring_probability),
      missing_info: job_card.missing_info
    })
    |> Ash.create()
  end

  def mount(_params, _session, socket) do
    socket = assign_new(socket, :current_user, fn -> nil end)

    CurriclickWeb.Endpoint.subscribe("chat:conversations:#{socket.assigns.current_user.id}")

    socket =
      socket
      |> assign(:page_title, "Chat")
      |> stream(
        :conversations,
        Curriclick.Chat.my_conversations!(actor: socket.assigns.current_user)
      )
      |> assign(:messages, [])
      |> assign(:loading_response, false)
      |> assign(:streamed_job_card_ids, MapSet.new())
      |> assign(:parsing_state, :finding_start)
      |> assign(:pending_tool_args, "")
      |> assign(:job_cards, [])
      |> stream(:job_cards, [], dom_id: &"job-#{&1.job_id}")
      |> assign(:selected_job_ids, MapSet.new())
      |> assign(:applied_job_ids, list_applied_job_ids(socket.assigns.current_user))
      |> assign(:failed_job_ids, MapSet.new())
      |> assign(:sort_by, :match)
      |> assign(:sort_order, :desc)
      |> assign(:show_jobs_panel, false)
      |> assign(:expanded_job_id, nil)

    {:ok, socket}
  end

  def handle_params(%{"conversation_id" => conversation_id}, _, socket) do
    conversation =
      Curriclick.Chat.get_conversation!(conversation_id, actor: socket.assigns.current_user)

    cond do
      socket.assigns[:conversation] && socket.assigns[:conversation].id == conversation.id ->
        :ok

      socket.assigns[:conversation] ->
        CurriclickWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
        Phoenix.PubSub.unsubscribe(Curriclick.PubSub, "chat:job_cards:#{socket.assigns.conversation.id}")
        CurriclickWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
        Phoenix.PubSub.subscribe(Curriclick.PubSub, "chat:job_cards:#{conversation.id}")

      true ->
        CurriclickWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
        Phoenix.PubSub.subscribe(Curriclick.PubSub, "chat:job_cards:#{conversation.id}")
    end

    job_cards = conversation.job_cards || []
    sorted_cards = sort_job_cards(job_cards, socket.assigns.sort_by, socket.assigns.sort_order)

    selected_ids =
      job_cards
      |> Enum.filter(& &1.selected)
      |> Enum.map(& &1.job_id)
      |> MapSet.new()

    socket
    |> assign(:conversation, conversation)
    |> stream(
      :messages,
      Curriclick.Chat.message_history!(conversation.id, query: [sort: [inserted_at: :asc]])
    )
    |> assign(:parsing_state, :finding_start)
    |> assign(:pending_tool_args, "")
    |> assign(:streamed_job_card_ids, MapSet.new())
    |> assign(:job_cards, sorted_cards)
    |> stream(:job_cards, sorted_cards, reset: true)
    |> assign(:selected_job_ids, selected_ids)
    |> assign(:show_jobs_panel, job_cards != [])
    |> assign(:expanded_job_id, nil)
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_params(_, _, socket) do
    if socket.assigns[:conversation] do
      CurriclickWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
      Phoenix.PubSub.unsubscribe(Curriclick.PubSub, "chat:job_cards:#{socket.assigns.conversation.id}")
    end

    socket
    |> assign(:conversation, nil)
    |> stream(:messages, [])
    |> assign(:parsing_state, :finding_start)
    |> assign(:pending_tool_args, "")
    |> assign(:streamed_job_card_ids, MapSet.new())
    |> assign(:job_cards, [])
    |> stream(:job_cards, [], reset: true)
    |> assign(:selected_job_ids, MapSet.new())
    |> assign(:show_jobs_panel, false)
    |> assign(:expanded_job_id, nil)
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_event("validate_message", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :message_form, AshPhoenix.Form.validate(socket.assigns.message_form, params))}
  end

  def handle_event("send_message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form, params: params) do
      {:ok, message} ->
        if socket.assigns.conversation do
          socket
          |> assign_message_form()
          |> stream_insert(:messages, message, at: -1)
          |> assign(:loading_response, true)
          |> then(&{:noreply, &1})
        else
          {:noreply,
           socket
           |> assign(:loading_response, true)
           |> push_patch(to: ~p"/chat/#{message.conversation_id}")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :message_form, form)}
    end
  end

  def handle_event("toggle_jobs_panel", _, socket) do
    {:noreply, assign(socket, :show_jobs_panel, !socket.assigns.show_jobs_panel)}
  end

  def handle_event("toggle_job_selection", %{"job_id" => job_id}, socket) do
    updated_job_cards =
      Enum.map(socket.assigns.job_cards, fn card ->
        if card.job_id == job_id do
          %{card | selected: !card.selected}
        else
          card
        end
      end)

    selected_job_ids =
      updated_job_cards
      |> Enum.filter(& &1.selected)
      |> Enum.map(& &1.job_id)
      |> MapSet.new()

    if socket.assigns.conversation do
      Curriclick.Chat.Conversation
      |> Ash.Query.filter(id == ^socket.assigns.conversation.id)
      |> Ash.read_one!(actor: socket.assigns.current_user)
      |> Ash.Changeset.for_update(:update_job_cards, %{job_cards: updated_job_cards},
        actor: socket.assigns.current_user
      )
      |> Ash.update!(actor: socket.assigns.current_user)
    end

    updated_card = Enum.find(updated_job_cards, & &1.job_id == job_id)

    {:noreply,
     socket
     |> assign(:job_cards, updated_job_cards)
     |> assign(:selected_job_ids, selected_job_ids)
     |> stream_insert(:job_cards, updated_card)}
  end

  def handle_event("expand_job_detail", %{"job_id" => job_id}, socket) do
    previous_job_id = socket.assigns.expanded_job_id
    socket = assign(socket, :expanded_job_id, job_id)

    socket =
      socket.assigns.job_cards
      |> Enum.filter(fn card -> card.job_id == job_id || card.job_id == previous_job_id end)
      |> Enum.reduce(socket, fn card, acc ->
        stream_insert(acc, :job_cards, card)
      end)

    {:noreply, socket}
  end

  def handle_event("collapse_job_detail", _, socket) do
    previous_job_id = socket.assigns.expanded_job_id
    socket = assign(socket, :expanded_job_id, nil)

    socket =
      if previous_job_id do
        case Enum.find(socket.assigns.job_cards, &(&1.job_id == previous_job_id)) do
          nil -> socket
          card -> stream_insert(socket, :job_cards, card)
        end
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("apply_to_job", %{"job_id" => job_id}, socket) do
    job_card = Enum.find(socket.assigns.job_cards, &(&1.job_id == job_id))

    if job_card do
      conversation_id = if socket.assigns.conversation, do: socket.assigns.conversation.id, else: nil

      case create_job_application(socket.assigns.current_user, job_card, "Chat job search", conversation_id) do
        {:ok, _} ->
          socket =
            socket
            |> assign(:applied_job_ids, MapSet.put(socket.assigns.applied_job_ids, job_id))
            |> put_flash(:info, "Candidatura enviada para #{job_card.title}!")

          {:noreply, socket}

        {:error, _} ->
          socket =
            socket
            |> assign(:failed_job_ids, MapSet.put(socket.assigns.failed_job_ids, job_id))
            |> put_flash(:error, "Erro ao enviar candidatura. Talvez você já tenha se candidatado.")

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("apply_to_selected", _, socket) do
    selected_jobs =
      socket.assigns.job_cards
      |> Enum.filter(&MapSet.member?(socket.assigns.selected_job_ids, &1.job_id))

    conversation_id = if socket.assigns.conversation, do: socket.assigns.conversation.id, else: nil

    results =
      Enum.map(selected_jobs, fn job_card ->
        {job_card.job_id,
         create_job_application(socket.assigns.current_user, job_card, "Chat job search (batch)", conversation_id)}
      end)

    success_ids =
      Enum.filter(results, fn {_, res} -> match?({:ok, _}, res) end)
      |> Enum.map(fn {id, _} -> id end)

    failed_ids =
      Enum.filter(results, fn {_, res} -> match?({:error, _}, res) end)
      |> Enum.map(fn {id, _} -> id end)

    success_count = length(success_ids)
    error_count = length(failed_ids)

    socket =
      cond do
        success_count > 0 && error_count == 0 ->
          put_flash(socket, :info, "#{success_count} candidatura(s) enviada(s) com sucesso!")

        success_count > 0 && error_count > 0 ->
          put_flash(socket, :warning, "#{success_count} enviada(s), #{error_count} falharam.")

        true ->
          put_flash(socket, :error, "Nenhuma candidatura nova enviada. Verifique se já se candidatou.")
      end

    new_applied_ids = MapSet.union(socket.assigns.applied_job_ids, MapSet.new(success_ids))
    new_failed_ids = MapSet.union(socket.assigns.failed_job_ids, MapSet.new(failed_ids))
    
    # Remove successful ones from selected, keep failed ones
    new_selected_ids =
      socket.assigns.selected_job_ids
      |> MapSet.difference(MapSet.new(success_ids))

    {:noreply,
     socket
     |> assign(:applied_job_ids, new_applied_ids)
     |> assign(:failed_job_ids, new_failed_ids)
     |> assign(:selected_job_ids, new_selected_ids)}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    sort_by = String.to_existing_atom(sort_by)
    sort_order = socket.assigns.sort_order
    
    # Toggle order if clicking same sort key? Or just set it.
    # Current plan says "New Assigns: @sort_by (default :match), @sort_order (default :desc)".
    # I'll assume the UI passes the desired sort or we toggle.
    # For now let's support setting sort_by and defaulting to desc.
    
    sorted_cards = sort_job_cards(socket.assigns.job_cards, sort_by, sort_order)
    
    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:job_cards, sorted_cards)
     |> stream(:job_cards, sorted_cards, reset: true)}
  end

  def handle_event("toggle_select_all", %{"value" => "on"}, socket) do
    # Select all unapplied jobs
    all_selectable_ids =
      socket.assigns.job_cards
      |> Enum.filter(fn card -> !MapSet.member?(socket.assigns.applied_job_ids, card.job_id) end)
      |> Enum.map(& &1.job_id)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_job_ids, all_selectable_ids)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    # Deselect all
    {:noreply, assign(socket, :selected_job_ids, MapSet.new())}
  end

  def handle_event("delete_conversation", %{"id" => id}, socket) do
    with {:ok, conversation} <-
           Curriclick.Chat.get_conversation(id, actor: socket.assigns.current_user),
         :ok <-
           Curriclick.Chat.delete_conversation(conversation, actor: socket.assigns.current_user) do
      socket =
        socket
        |> stream_delete(:conversations, conversation)
        |> maybe_reset_deleted_conversation(conversation)

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Erro ao excluir a conversa.")}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:messages:" <> conversation_id,
          payload: message
        },
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      socket =
        if message.source != :user do
          assign(socket, :loading_response, !message.complete)
        else
          socket
        end

      {:noreply, stream_insert(socket, :messages, message, at: -1)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:conversations:" <> _,
          payload: {event_type, conversation}
        },
        socket
      ) do
    socket =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation.id do
        assign(socket, :conversation, conversation)
      else
        socket
      end

    opts = if event_type == :create, do: [at: 0], else: []
    {:noreply, stream_insert(socket, :conversations, conversation, opts)}
  end

  def handle_info(
        {:tool_call_delta, %{conversation_id: conversation_id, tool_calls: tool_calls}},
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      # Accumulate arguments from delta
      new_args_chunk =
        Enum.reduce(tool_calls, "", fn call, acc ->
          args =
            Map.get(call, :arguments) ||
              Map.get(call, "arguments") ||
              (
                func = Map.get(call, :function)
                if is_map(func), do: Map.get(func, :arguments)
              ) ||
              (
                func = Map.get(call, "function")
                if is_map(func), do: Map.get(func, "arguments")
              )

          acc <> (args || "")
        end)

      current_buffer = socket.assigns.pending_tool_args <> new_args_chunk

      {new_buffer, new_cards} =
        case socket.assigns.parsing_state do
          :finding_start ->
            case :binary.match(current_buffer, ["\"job_cards\":", "\"job_cards\" :"]) do
              {pos, len} ->
                # Found start of job_cards key
                after_key = binary_part(current_buffer, pos + len, byte_size(current_buffer) - (pos + len))
                case :binary.match(after_key, "[") do
                  {start_pos, 1} ->
                     # Found start of array
                     array_content = binary_part(after_key, start_pos + 1, byte_size(after_key) - (start_pos + 1))
                     {cards, remainder} = parse_json_objects(array_content)
                     {remainder, cards}
                  :nomatch ->
                     # Key found but array start not yet
                     {current_buffer, []}
                end
              :nomatch ->
                {current_buffer, []}
            end

          :inside_array ->
             {cards, remainder} = parse_json_objects(current_buffer)
             {remainder, cards}
        end

      new_state =
        if socket.assigns.parsing_state == :finding_start && new_buffer != current_buffer do
          :inside_array
        else
          socket.assigns.parsing_state
        end

      socket =
        Enum.reduce(new_cards, socket, fn card_map, s ->
          # Convert to struct-like map with atom keys
          card_atom = keys_to_atoms(card_map)
          # Ensure job_id is present (it should be)
          if card_atom[:job_id] && !MapSet.member?(s.assigns.streamed_job_card_ids, card_atom.job_id) do
             # Add defaults if missing
             card_struct = struct(Curriclick.Companies.JobCardPresentation, card_atom)
             
             new_list = s.assigns.job_cards ++ [card_struct]
             sorted = sort_job_cards(new_list, s.assigns.sort_by, s.assigns.sort_order)

             s
             |> assign(:job_cards, sorted)
             |> stream(:job_cards, sorted, reset: true)
             |> assign(:streamed_job_card_ids, MapSet.put(s.assigns.streamed_job_card_ids, card_struct.job_id))
             |> assign(:show_jobs_panel, true)
          else
             s
          end
        end)

      {:noreply,
       socket
       |> assign(:pending_tool_args, new_buffer)
       |> assign(:parsing_state, new_state)
       |> assign(:loading_response, true)} # Keep loading dots
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:job_cards_updated, %{job_cards: job_cards, conversation_id: conversation_id}},
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      # Pre-select jobs marked as selected by the LLM
      selected_ids =
        job_cards
        |> Enum.filter(& &1.selected)
        |> Enum.map(& &1.job_id)
        |> MapSet.new()

      sorted_cards = sort_job_cards(job_cards, socket.assigns.sort_by, socket.assigns.sort_order)

      {:noreply,
       socket
       |> assign(:job_cards, sorted_cards)
       |> assign(:selected_job_ids, selected_ids)
       |> assign(:show_jobs_panel, job_cards != [])
       |> stream(:job_cards, sorted_cards, reset: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:job_cards_reset, %{conversation_id: conversation_id}},
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      {:noreply,
       socket
       |> assign(:job_cards, [])
       |> assign(:streamed_job_card_ids, MapSet.new())
       |> assign(:parsing_state, :finding_start)
       |> assign(:pending_tool_args, "")
       |> assign(:show_jobs_panel, true) # Keep panel open or open it
       |> stream(:job_cards, [], reset: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:job_card_added, %{job_card: job_card, conversation_id: conversation_id}},
        socket
      ) do
    if socket.assigns.conversation && socket.assigns.conversation.id == conversation_id do
      # Handle pre-selection for this card
      selected_ids =
        if job_card.selected do
          MapSet.put(socket.assigns.selected_job_ids, job_card.job_id)
        else
          socket.assigns.selected_job_ids
        end

      new_job_cards = socket.assigns.job_cards ++ [job_card]
      sorted_cards = sort_job_cards(new_job_cards, socket.assigns.sort_by, socket.assigns.sort_order)

      {:noreply,
       socket
       |> assign(:job_cards, sorted_cards)
       |> assign(:selected_job_ids, selected_ids)
       |> assign(:show_jobs_panel, true)
       |> stream(:job_cards, sorted_cards, reset: true)}
    else
      {:noreply, socket}
    end
  end

  defp assign_message_form(socket) do
    form =
      if socket.assigns.conversation do
        Curriclick.Chat.form_to_create_message(
          actor: socket.assigns.current_user,
          private_arguments: %{conversation_id: socket.assigns.conversation.id}
        )
        |> to_form()
      else
        Curriclick.Chat.form_to_create_message(actor: socket.assigns.current_user)
        |> to_form()
      end

    assign(
      socket,
      :message_form,
      form
    )
  end

  defp maybe_reset_deleted_conversation(socket, conversation) do
    if socket.assigns[:conversation] && socket.assigns.conversation.id == conversation.id do
      CurriclickWeb.Endpoint.unsubscribe("chat:messages:#{conversation.id}")
      Phoenix.PubSub.unsubscribe(Curriclick.PubSub, "chat:job_cards:#{conversation.id}")

      socket
      |> assign(:conversation, nil)
      |> stream(:messages, [], reset: true)
      |> assign(:job_cards, [])
      |> stream(:job_cards, [], reset: true)
      |> assign(:streamed_job_card_ids, MapSet.new())
      |> assign(:parsing_state, :finding_start)
      |> assign(:pending_tool_args, "")
      |> assign_message_form()
      |> push_patch(to: ~p"/chat")
    else
      socket
    end
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
  defp parse_json_objects(binary, acc \\ []) do
    # Skip whitespace/commas
    binary = String.trim_leading(binary, ", \n\r\t")

    if String.starts_with?(binary, "{") do
      case find_matching_brace(binary) do
        {:ok, object_str, rest} ->
          case Jason.decode(object_str) do
            {:ok, object} ->
              parse_json_objects(rest, acc ++ [object])
            _ ->
              # Decode failed, maybe incomplete? Should not happen if braces matched correctly
              # unless JSON inside is invalid.
              # If invalid, we stop parsing this chunk.
              {acc, binary}
          end
        :incomplete ->
          {acc, binary}
      end
    else
      # If we don't see '{', maybe we are at ']' or end of buffer or just whitespace
      if String.starts_with?(binary, "]") do
         # End of array.
         {acc, ""}
      else
         # Incomplete or garbage. Keep buffer.
         {acc, binary}
      end
    end
  end

  defp find_matching_brace(binary) do
     case do_scan_braces(binary, 0, 0) do
       {:match, length} ->
         <<object::binary-size(length), rest::binary>> = binary
         {:ok, object, rest}
       :incomplete ->
         :incomplete
     end
  end

  defp do_scan_braces(<<?{, rest::binary>>, index, 0) do
    do_scan_braces(rest, index + 1, 1)
  end

  defp do_scan_braces(<<?{, rest::binary>>, index, count) do
    do_scan_braces(rest, index + 1, count + 1)
  end

  defp do_scan_braces(<<?}, rest::binary>>, index, count) do
    if count == 1 do
      {:match, index + 1}
    else
      do_scan_braces(rest, index + 1, count - 1)
    end
  end

  defp do_scan_braces(<<_, rest::binary>>, index, count) do
    do_scan_braces(rest, index + 1, count)
  end

  defp do_scan_braces("", _index, _count), do: :incomplete

  defp keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), keys_to_atoms(v)} end)
  end
  defp keys_to_atoms(list) when is_list(list), do: Enum.map(list, &keys_to_atoms/1)
  defp keys_to_atoms(v), do: v

  defp list_applied_job_ids(user) do
    Curriclick.Companies.JobApplication
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.select([:job_listing_id])
    |> Ash.read!(actor: user)
    |> Enum.map(& &1.job_listing_id)
    |> MapSet.new()
  end

  defp sort_job_cards(cards, sort_by, sort_order) do
    Enum.sort_by(cards, fn card ->
      case sort_by do
        :match ->
          {match_quality_score(card.match_quality), probability_score(card.hiring_probability)}
        :probability ->
          probability_score(card.hiring_probability)
      end
    end, sort_order)
  end

  defp probability_score(%{score: :high}), do: 3
  defp probability_score(%{score: :medium}), do: 2
  defp probability_score(%{score: :low}), do: 1
  defp probability_score(_), do: 0

  defp match_quality_score(%{score: :good_match}), do: 3
  defp match_quality_score(%{score: :moderate_match}), do: 2
  defp match_quality_score(%{score: :bad_match}), do: 1
  defp match_quality_score(_), do: 0

  defp sanitize_score(nil), do: nil

  defp sanitize_score(%_{} = score) do
    Map.from_struct(score)
    |> Map.drop([
      :__meta__,
      :__metadata__,
      :__order__,
      :__lateral_join_source__,
      :aggregates,
      :calculations
    ])
  end

  defp sanitize_score(other), do: other
end
