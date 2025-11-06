defmodule CurriclickWeb.PageControllerTest do
  use CurriclickWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~s(<div id="app"></div>)
    assert response =~ ~s(src="/assets/js/job-listings.js")
  end
end
