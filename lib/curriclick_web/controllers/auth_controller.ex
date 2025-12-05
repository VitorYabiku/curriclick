defmodule CurriclickWeb.AuthController do
  @moduledoc """
  Controller for handling authentication callbacks (success/failure/sign_out).
  """
  use CurriclickWeb, :controller
  use AshAuthentication.Phoenix.Controller

  @spec success(Plug.Conn.t(), any(), any(), any()) :: Plug.Conn.t()
  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Seu endereço de e-mail foi confirmado"
        {:password, :reset} -> "Sua senha foi redefinida com sucesso"
        _ -> "Você entrou com sucesso"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  @spec failure(Plug.Conn.t(), any(), any()) :: Plug.Conn.t()
  def failure(conn, activity, reason) do
    message =
      case {activity, reason} do
        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          Você já entrou de outra forma, mas não confirmou sua conta.
          Você pode confirmar sua conta usando o link que enviamos para você, ou redefinindo sua senha.
          """

        _ ->
          "E-mail ou senha incorretos"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  @spec sign_out(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:curriclick)
    |> put_flash(:info, "Você saiu com sucesso")
    |> redirect(to: return_to)
  end
end
