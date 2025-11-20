defmodule CurriclickWeb.ChatLive do
  use Elixir.CurriclickWeb, :live_view
  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  def render(assigns) do
    ~H"""
    <div class="drawer md:drawer-open h-[calc(100vh-10rem)] rounded-xl overflow-hidden border border-base-300 bg-base-100 shadow-sm">
      <input id="ash-ai-drawer" type="checkbox" class="drawer-toggle" />
      
      <!-- Main Content -->
      <div class="drawer-content flex flex-col relative">
        <!-- Mobile Header -->
        <div class="navbar bg-base-100 w-full md:hidden border-b border-base-200 min-h-12">
          <div class="flex-none">
            <label for="ash-ai-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost btn-sm">
              <.icon name="hero-bars-3" class="w-5 h-5" />
            </label>
          </div>
          <div class="flex-1 px-2 mx-2 text-sm font-semibold">Curriclick AI</div>
        </div>

        <!-- Messages Area -->
        <div class="flex-1 overflow-y-auto p-4 scroll-smooth flex flex-col-reverse" id="message-container" phx-update="stream">
          <%= for {id, message} <- @streams.messages do %>
            <div
              id={id}
              class={[
                "chat group mb-2",
                message.source == :user && "chat-end",
                message.source == :agent && "chat-start"
              ]}
            >
              <div :if={message.source == :agent} class="chat-image avatar">
                <div class="w-8 h-8 rounded-full bg-base-200 p-1 border border-base-300 flex items-center justify-center">
                  <img src={~p"/images/logo.svg"} alt="AI" class="w-full h-full object-contain" />
                </div>
              </div>
              <div :if={message.source == :user} class="chat-image avatar placeholder">
                <div class="bg-neutral text-neutral-content rounded-full w-8 h-8">
                  <span class="text-xs">YOU</span>
                </div>
              </div>
              
              <div :if={message.source == :agent} class="chat-header opacity-50 text-xs mb-1 ml-1">
                Curriclick AI
              </div>
              
              <div class={[
                "chat-bubble shadow-sm text-sm",
                message.source == :user && "chat-bubble-primary text-primary-content",
                message.source == :agent && "bg-base-200 text-base-content"
              ]}>
                {to_markdown(message.text)}
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
                  <h1 class="text-2xl font-bold">How can I help you today?</h1>
                  <p class="py-4 text-sm text-base-content/70">
                    Ask me anything about your curriculum, job search, or career advice.
                  </p>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Input Area -->
        <div class="p-4 bg-base-100/80 backdrop-blur-md sticky bottom-0 z-10 w-full">
          <.form
            :let={form}
            for={@message_form}
            phx-change="validate_message"
            phx-submit="send_message"
            class="relative max-w-3xl mx-auto"
          >
            <div class="join w-full shadow-lg rounded-2xl border border-base-300 bg-base-100 p-1.5 focus-within:ring-2 focus-within:ring-primary/20 transition-all">
              <input
                name={form[:text].name}
                value={form[:text].value}
                type="text"
                phx-mounted={JS.focus()}
                placeholder="Message Curriclick AI..."
                class="input input-ghost join-item w-full focus:outline-none focus:bg-transparent h-auto py-3 text-base border-none bg-transparent pl-4"
                autocomplete="off"
              />
              
              <button type="submit" class="btn btn-primary btn-circle btn-sm h-8 w-8 self-center mr-1 shadow-sm" disabled={!form[:text].value || form[:text].value == ""}>
                <.icon name="hero-arrow-up" class="w-4 h-4" />
              </button>
            </div>
            <div class="text-center mt-2">
              <span class="text-[10px] text-base-content/40">AI can make mistakes. Check important info.</span>
            </div>
          </.form>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="drawer-side h-full absolute md:relative z-20">
        <label for="ash-ai-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <div class="menu p-4 w-72 h-full bg-base-50 border-r border-base-200 text-base-content flex flex-col">
          <!-- Sidebar Header -->
          <div class="flex items-center gap-2 mb-6 px-2">
            <div class="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center text-primary font-bold">
              <img src={~p"/images/logo.svg"} alt="Logo" class="w-5 h-5" />
            </div>
            <span class="font-bold text-sm tracking-tight">Curriclick</span>
          </div>

          <!-- New Chat Button -->
          <div class="mb-4">
            <.link navigate={~p"/chat"} class="btn btn-primary btn-sm btn-block justify-start gap-2 normal-case font-medium shadow-sm">
              <.icon name="hero-plus" class="w-4 h-4" />
              New chat
            </.link>
          </div>

          <div class="flex-1 overflow-y-auto -mx-2 px-2">
            <div class="text-[10px] font-bold text-base-content/40 uppercase tracking-wider mb-2 px-2">
              Recent
            </div>
            <ul class="space-y-0.5" phx-update="stream" id="conversations-list">
              <%= for {id, conversation} <- @streams.conversations do %>
                <li id={id}>
                  <.link
                    navigate={~p"/chat/#{conversation.id}"}
                    phx-click="select_conversation"
                    phx-value-id={conversation.id}
                    class={[
                      "group flex items-center gap-2 rounded-md px-3 py-2 text-sm transition-all hover:bg-base-200",
                      if(@conversation && @conversation.id == conversation.id, do: "bg-base-200 font-medium text-base-content", else: "text-base-content/70")
                    ]}
                  >
                    <span class="truncate flex-1">
                      {build_conversation_title_string(conversation.title)}
                    </span>
                  </.link>
                </li>
              <% end %>
            </ul>
          </div>

          <!-- Footer -->
          <div class="mt-auto pt-4 border-t border-base-200">
             <!-- User info or settings could go here -->
          </div>
        </div>
      </div>
    </div>
    """
  end

  def build_conversation_title_string(title) do
    cond do
      title == nil -> "Untitled conversation"
      is_binary(title) && String.length(title) > 25 -> String.slice(title, 0, 25) <> "..."
      is_binary(title) && String.length(title) <= 25 -> title
    end
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
        CurriclickWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")

      true ->
        CurriclickWeb.Endpoint.subscribe("chat:messages:#{conversation.id}")
    end

    socket
    |> assign(:conversation, conversation)
    |> stream(:messages, Curriclick.Chat.message_history!(conversation.id, stream?: true))
    |> assign_message_form()
    |> then(&{:noreply, &1})
  end

  def handle_params(_, _, socket) do
    if socket.assigns[:conversation] do
      CurriclickWeb.Endpoint.unsubscribe("chat:messages:#{socket.assigns.conversation.id}")
    end

    socket
    |> assign(:conversation, nil)
    |> stream(:messages, [])
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
          |> stream_insert(:messages, message, at: 0)
          |> then(&{:noreply, &1})
        else
          {:noreply,
           socket
           |> push_navigate(to: ~p"/chat/#{message.conversation_id}")}
        end

      {:error, form} ->
        {:noreply, assign(socket, :message_form, form)}
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
      {:noreply, stream_insert(socket, :messages, message, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "chat:conversations:" <> _,
          payload: conversation
        },
        socket
      ) do
    socket =
      if socket.assigns.conversation && socket.assigns.conversation.id == conversation.id do
        assign(socket, :conversation, conversation)
      else
        socket
      end

    {:noreply, stream_insert(socket, :conversations, conversation)}
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
