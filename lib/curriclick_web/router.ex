defmodule CurriclickWeb.Router do
  use CurriclickWeb, :router

  import Oban.Web.Router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CurriclickWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :put_layout, html: {CurriclickWeb.Layouts, :app}
  end

  pipeline :api do
    plug :accepts, ["json"]

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Curriclick.Accounts.User,
      # if you want to require an api key to be supplied, set `required?` to true
      required?: false

    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", CurriclickWeb do
    pipe_through :browser

    ash_authentication_live_session :chat_routes, layout: {CurriclickWeb.Layouts, :chat} do
      live "/chat", ChatLive
      live "/chat/:conversation_id", ChatLive
    end

    ash_authentication_live_session :authenticated_routes, layout: {CurriclickWeb.Layouts, :app} do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {CurriclickWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {CurriclickWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {CurriclickWeb.LiveUserAuth, :live_no_user}

      live "/dashboard", UserDashboardLive
      live "/profile", UserProfileLive
    end

    post "/rpc/run", AshTypescriptRpcController, :run
    post "/rpc/validate", AshTypescriptRpcController, :validate

    ash_authentication_live_session :public_jobs, layout: {CurriclickWeb.Layouts, :app} do
      live "/", JobsLive
      # get "/jobs", PageController, :jobs
    end
  end

  scope "/", CurriclickWeb do
    pipe_through :browser

    # get "/", PageController, :home
    auth_routes AuthController, Curriclick.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{CurriclickWeb.LiveUserAuth, :live_no_user}],
                  layout: {CurriclickWeb.Layouts, :app},
                  gettext_backend: {CurriclickWeb.Gettext, "auth"},
                  overrides: [
                    CurriclickWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                layout: {CurriclickWeb.Layouts, :app},
                gettext_backend: {CurriclickWeb.Gettext, "auth"},
                overrides: [
                  CurriclickWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]

    # Remove this if you do not use the confirmation strategy
    confirm_route Curriclick.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      layout: {CurriclickWeb.Layouts, :app},
      gettext_backend: {CurriclickWeb.Gettext, "auth"},
      overrides: [CurriclickWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Curriclick.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      layout: {CurriclickWeb.Layouts, :app},
      gettext_backend: {CurriclickWeb.Gettext, "auth"},
      overrides: [CurriclickWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", CurriclickWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:curriclick, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CurriclickWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end

  if Application.compile_env(:curriclick, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
