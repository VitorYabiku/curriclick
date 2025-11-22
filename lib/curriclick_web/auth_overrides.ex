defmodule CurriclickWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  # configure your UI overrides here

  # First argument to `override` is the component name you are overriding.
  # The body contains any number of configurations you wish to override
  # Below are some examples

  # For a complete reference, see https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html

  override AshAuthentication.Phoenix.Components.Banner do
    set :text, "Entre na sua conta"
  end

  override AshAuthentication.Phoenix.Components.Password.SignInForm do
    set :button_text, "Entrar"
    set :disable_button_text, "Entrando..."
  end

  override AshAuthentication.Phoenix.Components.Password.RegisterForm do
    set :button_text, "Registrar"
    set :disable_button_text, "Registrando..."
  end

  override AshAuthentication.Phoenix.Components.Password.ResetForm do
    set :button_text, "Redefinir Senha"
    set :disable_button_text, "Redefinindo..."
  end

  override AshAuthentication.Phoenix.Components.Password.Input do
    set :identity_input_label, "E-mail"
    set :identity_input_placeholder, "exemplo@email.com"
    set :password_input_label, "Senha"
    set :password_confirmation_input_label, "Confirmar Senha"
  end
end
