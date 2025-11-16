defmodule CurriclickWeb.PageControllerTest do
  use CurriclickWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~s(Vagas)
  end
end
