defmodule CurriclickWeb.AshTypescriptRpcController do
  @moduledoc """
  Controller for handling AshTypescript RPC requests.
  """
  use CurriclickWeb, :controller

  @spec run(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:curriclick, conn, params)
    json(conn, result)
  end

  @spec validate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:curriclick, conn, params)
    json(conn, result)
  end
end
