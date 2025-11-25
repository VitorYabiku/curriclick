defmodule CurriclickWeb.UserProfileLive do
  use CurriclickWeb, :live_view

  alias Curriclick.Accounts

  on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}

  def mount(_params, _session, socket) do
    form =
      Accounts.form_to_update_profile(socket.assigns.current_user,
        actor: socket.assigns.current_user
      )
      |> to_form()

    remote_flags = remote_flags(socket.assigns.current_user.profile_remote_preference)

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:remote_flags, remote_flags)}
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

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-base-200/60 via-base-200/30 to-base-100">
      <div class="max-w-5xl mx-auto px-4 pb-12 pt-8 space-y-6">
        <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
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
          <.link navigate={~p"/dashboard"} class="btn btn-outline btn-primary btn-sm md:btn-md">
            Ver candidaturas
          </.link>
        </div>

        <div>
          <.form
            for={@form}
            phx-change="validate"
            phx-submit="save"
            class="card bg-base-100/95 shadow-xl border border-base-300/70 backdrop-blur-sm"
          >
            <div class="card-body grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="space-y-3">
                <.input
                  field={@form[:profile_job_interests]}
                  label="Interesses profissionais / cargos"
                  label_class="text-sm font-semibold text-base-content/80"
                  class="w-full input input-bordered input-md lg:input-lg text-base"
                  placeholder="Ex.: Desenvolvedor backend Elixir, APIs, produtos B2B"
                />

                <.input
                  field={@form[:profile_skills]}
                  label="Principais habilidades"
                  label_class="text-sm font-semibold text-base-content/80"
                  class="w-full input input-bordered input-md lg:input-lg text-base"
                  placeholder="Ex.: Elixir, Phoenix, PostgreSQL, AWS, liderança técnica"
                />

                <.input
                  type="textarea"
                  field={@form[:profile_experience]}
                  rows="3"
                  label="Resumo da experiência"
                  label_class="text-sm font-semibold text-base-content/80"
                  class="w-full textarea textarea-bordered text-base leading-relaxed"
                  placeholder="Ex.: 4 anos desenvolvendo serviços web, liderança de squad por 1 ano"
                />

                <.input
                  type="textarea"
                  field={@form[:profile_custom_instructions]}
                  rows="5"
                  label="Instruções para a IA"
                  label_class="text-sm font-semibold text-base-content/80"
                  class="w-full textarea textarea-bordered text-base leading-relaxed"
                  placeholder="Tom de voz, preferências de vaga, o que evitar, como priorizar resultados"
                />
              </div>

              <div class="space-y-3">
                <.input
                  type="textarea"
                  field={@form[:profile_education]}
                  rows="3"
                  label="Educação e cursos"
                  label_class="text-sm font-semibold text-base-content/80"
                  class="w-full textarea textarea-bordered text-base leading-relaxed"
                  placeholder="Graduação, certificações, cursos relevantes"
                />
              </div>

              <div class="md:col-span-2 space-y-3 rounded-xl border border-base-300/70 bg-base-200/60 p-4 shadow-sm">
                <div class="space-y-1">
                  <p class="text-sm font-semibold text-base-content/90">
                    Preferência de modalidade
                  </p>
                  <p class="text-sm text-base-content/70">
                    Escolha as modalidades que você aceita.
                  </p>
                </div>

                <div class="grid grid-cols-1 gap-2 md:grid-cols-3">
                  <label class="flex w-full items-start justify-between gap-3 rounded-lg border border-base-300/60 bg-base-100 px-3 py-2 shadow-sm">
                    <div class="min-w-0 space-y-1 break-words">
                      <p class="font-semibold text-base-content/90">Remoto</p>
                      <p class="text-sm text-base-content/70">Trabalhar 100% à distância.</p>
                    </div>
                    <div class="join shrink-0">
                      <input
                        type="radio"
                        name="form[remote_remote]"
                        value="true"
                        checked={@remote_flags.remote}
                        class={[
                          "join-item btn btn-sm md:btn-md",
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
                          "join-item btn btn-sm md:btn-md",
                          !@remote_flags.remote && "btn-primary",
                          @remote_flags.remote && "btn-ghost"
                        ]}
                        aria-label="Não"
                      />
                    </div>
                  </label>

                  <label class="flex w-full items-start justify-between gap-3 rounded-lg border border-base-300/60 bg-base-100 px-3 py-2 shadow-sm">
                    <div class="min-w-0 space-y-1 break-words">
                      <p class="font-semibold text-base-content/90">Híbrido</p>
                      <p class="text-sm text-base-content/70">
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
                          "join-item btn btn-sm md:btn-md",
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
                          "join-item btn btn-sm md:btn-md",
                          !@remote_flags.hybrid && "btn-primary",
                          @remote_flags.hybrid && "btn-ghost"
                        ]}
                        aria-label="Não"
                      />
                    </div>
                  </label>

                  <label class="flex w-full items-start justify-between gap-3 rounded-lg border border-base-300/60 bg-base-100 px-3 py-2 shadow-sm md:col-span-1">
                    <div class="min-w-0 space-y-1 break-words">
                      <p class="font-semibold text-base-content/90">Presencial</p>
                      <p class="text-sm text-base-content/70">Atuação no escritório / cliente.</p>
                    </div>
                    <div class="join shrink-0">
                      <input
                        type="radio"
                        name="form[remote_on_site]"
                        value="true"
                        checked={@remote_flags.on_site}
                        class={[
                          "join-item btn btn-sm md:btn-md",
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
                          "join-item btn btn-sm md:btn-md",
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

            <div class="card-actions border-t border-base-300/70 px-6 py-4 bg-base-200/60 flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
              <div class="alert bg-base-200/80 border border-base-300 text-base-content/80 shadow-sm w-full md:max-w-xl">
                <.icon name="hero-information-circle" class="h-5 w-5 text-primary" />
                <div class="space-y-1">
                  <p class="font-semibold text-base-content/90">Dicas rápidas</p>
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
    """
  end

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

  defp truthy?(value) do
    case value do
      true -> true
      "true" -> true
      "on" -> true
      "1" -> true
      _ -> false
    end
  end

  defp preference_from_flags(%{remote: true, hybrid: true, on_site: true}), do: :no_preference
  defp preference_from_flags(%{remote: true, hybrid: true, on_site: false}), do: :remote_friendly
  defp preference_from_flags(%{remote: true, hybrid: false, on_site: false}), do: :remote_only
  defp preference_from_flags(%{remote: false, hybrid: true, on_site: false}), do: :hybrid
  defp preference_from_flags(%{remote: false, hybrid: false, on_site: true}), do: :on_site
  defp preference_from_flags(%{remote: true, hybrid: false, on_site: true}), do: :hybrid
  defp preference_from_flags(%{remote: false, hybrid: true, on_site: true}), do: :hybrid
  defp preference_from_flags(_), do: :no_preference

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
