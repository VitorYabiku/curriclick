defmodule CurriclickWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use CurriclickWeb, :verified_routes
  require Ash.Query

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {CurriclickWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    if socket.assigns[:current_user] do
      socket = assign_draft_count(socket)
      {:cont, socket}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      socket = assign_draft_count(socket)
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  defp assign_draft_count(socket) do
    user = socket.assigns.current_user

    if Phoenix.LiveView.connected?(socket) do
      CurriclickWeb.Endpoint.subscribe("user_applications:#{user.id}")
    end

    socket =
      Phoenix.LiveView.attach_hook(
        socket,
        :draft_count_updates,
        :handle_info,
        &handle_draft_count_update/2
      )

    count =
      Curriclick.Companies.JobApplication
      |> Ash.Query.filter(user_id == ^user.id and status == :draft)
      |> Ash.count!()

    assign(socket, :draft_count, count)
  end

  defp handle_draft_count_update(
         %Phoenix.Socket.Broadcast{
           topic: "user_applications:" <> _,
           payload: %Ash.Notifier.Notification{resource: Curriclick.Companies.JobApplication}
         },
         socket
       ) do
    user = socket.assigns.current_user

    count =
      Curriclick.Companies.JobApplication
      |> Ash.Query.filter(user_id == ^user.id and status == :draft)
      |> Ash.count!()

    {:cont, assign(socket, :draft_count, count)}
  end

  defp handle_draft_count_update(_, socket), do: {:cont, socket}
end
