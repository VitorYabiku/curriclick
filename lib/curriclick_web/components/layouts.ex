defmodule CurriclickWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use CurriclickWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  @doc """
  Renders the application header.
  """
  attr :current_user, :map, default: nil

  def app_header(assigns) do
    ~H"""
    <header class="navbar sticky top-0 z-50 bg-base-200/90 backdrop-blur border-b border-base-200">
      <div class="flex-1">
        <a href={~p"/"} class="btn btn-ghost text-xl">Curriclick</a>
      </div>
      <div class="flex-none">
        <ul class="menu menu-horizontal px-1 gap-2 items-center">
          <%= if @current_user do %>
            <li>
              <.link navigate={~p"/chat"}>Busca de empregos</.link>
            </li>
            <li>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost px-2 gap-2">
                  <div class="avatar placeholder">
                    <div class="bg-neutral text-neutral-content rounded-full w-8">
                      <span class="text-xs">
                        {@current_user.email |> to_string() |> String.slice(0, 2) |> String.upcase()}
                      </span>
                    </div>
                  </div>
                  <.icon name="hero-chevron-down" class="w-4 h-4 opacity-50" />
                </div>
                <ul
                  tabindex="0"
                  class="mt-3 z-[1] p-2 shadow menu menu-sm dropdown-content rounded-box w-max bg-base-200"
                >
                  <li>
                    <.theme_toggle />
                  </li>
                  <li>
                    <.link href={~p"/profile"} class="text-lg">Meu perfil</.link>
                  </li>
                  <li>
                    <.link href={~p"/dashboard"} class="text-lg">Suas candidaturas</.link>
                  </li>
                  <li>
                    <.link
                      href={~p"/sign-out"}
                      class="text-error text-lg"
                      data-confirm="Tem certeza de que deseja sair?"
                    >
                      Sair
                    </.link>
                  </li>
                </ul>
              </div>
            </li>
          <% else %>
            <li>
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-ghost btn-circle">
                  <.icon name="hero-swatch" class="size-5" />
                </div>
                <ul
                  tabindex="0"
                  class="mt-3 z-[1] p-2 shadow menu menu-sm dropdown-content rounded-box w-max bg-base-200"
                >
                  <li>
                    <.theme_toggle />
                  </li>
                </ul>
              </div>
            </li>
            <li><.link navigate={~p"/sign-in"}>Entrar</.link></li>
            <li>
              <.link navigate={~p"/register"} class="btn btn-primary btn-sm text-primary-content">
                Cadastrar-se
              </.link>
            </li>
          <% end %>
        </ul>
      </div>
    </header>
    """
  end
end
