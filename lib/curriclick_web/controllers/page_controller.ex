defmodule CurriclickWeb.PageController do
  @moduledoc """
  Controller for static pages.
  """
  use CurriclickWeb, :controller

  @spec home(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def home(conn, _params) do
    render(conn, :home)
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index conn, _params do
    render(conn, :index)
  end

  @spec jobs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def jobs(conn, _params) do
    render(conn, :jobs)
  end
end
