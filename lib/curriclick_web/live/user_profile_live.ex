defmodule CurriclickWeb.UserProfileLive do
  use CurriclickWeb, :live_view

  alias Curriclick.Accounts

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  @remote_options [
    {"Remoto apenas", :remote_only},
    {"Remoto / híbrido", :remote_friendly},
    {"Híbrido", :hybrid},
    {"Presencial", :on_site},
    {"Sem preferência", :no_preference}
  ]

  def mount(_params, _session, socket) do
    form =
      Accounts.form_to_update_profile(socket.assigns.current_user,
        actor: socket.assigns.current_user
      )
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:remote_preference_options, @remote_options)}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params) |> to_form())}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, user} ->
        form = Accounts.form_to_update_profile(user, actor: user) |> to_form()

        {:noreply,
         socket
         |> put_flash(:info, "Perfil salvo.")
         |> assign(:current_user, user)
         |> assign(:form, form)}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto p-4 space-y-6">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm uppercase tracking-wide text-base-content/60 font-semibold">Perfil</p>
          <h1 class="text-3xl font-bold">Preferências e instruções</h1>
          <p class="text-base-content/70 mt-1">Guarde suas informações para personalizar buscas e respostas da IA.</p>
        </div>
        <.link navigate={~p"/dashboard"} class="btn btn-ghost">Ver candidaturas</.link>
      </div>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="save"
        class="card bg-base-100 shadow-lg border border-base-200"
      >
        <div class="card-body grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-3">
            <.input
              field={@form[:profile_job_interests]}
              label="Interesses profissionais / cargos"
              placeholder="Ex.: Desenvolvedor backend Elixir, APIs, produtos B2B"
            />

            <.input
              field={@form[:profile_skills]}
              label="Principais habilidades"
              placeholder="Ex.: Elixir, Phoenix, PostgreSQL, AWS, liderança técnica"
            />

            <.input
              type="textarea"
              field={@form[:profile_experience]}
              rows="3"
              label="Resumo da experiência"
              placeholder="Ex.: 4 anos desenvolvendo serviços web, liderança de squad por 1 ano"
            />

            <.input
              type="select"
              field={@form[:profile_remote_preference]}
              label="Preferência de modalidade"
              options={@remote_preference_options}
              prompt="Escolha"
            />
          </div>

          <div class="space-y-3">
            <.input
              type="textarea"
              field={@form[:profile_education]}
              rows="3"
              label="Educação e cursos"
              placeholder="Graduação, certificações, cursos relevantes"
            />

            <.input
              type="textarea"
              field={@form[:profile_custom_instructions]}
              rows="5"
              label="Instruções para a IA"
              placeholder="Tom de voz, preferências de vaga, o que evitar, como priorizar resultados"
            />

            <div class="flex flex-wrap gap-2 text-sm text-base-content/70">
              <span class="badge badge-outline text-info">Campos podem ser deixados em branco para limpar</span>
              <span class="badge badge-outline text-info">Alterações valem para buscas futuras e chat</span>
            </div>
          </div>
        </div>

        <div class="card-actions justify-end border-t border-base-200 px-6 py-4 bg-base-200/40">
          <button type="submit" class="btn btn-primary">Salvar perfil</button>
        </div>
      </.form>
    </div>
    """
  end
end
