defmodule ElixirTestProjectWeb.Plugs.RequireAuthPlugTest do
  use ElixirTestProjectWeb.ConnCase, async: true

  test "returns 401 when current_user is nil", %{conn: conn} do
    conn = ElixirTestProjectWeb.Plugs.RequireAuthPlug.call(conn, %{})
    assert conn.status == 401
    assert json_response(conn, 401)["error"] == "unauthorized"
  end

  test "passes when current_user is present", %{conn: conn} do
    # Simulate presence of current_user by assigning it before calling the plug route
    conn =
      conn = conn |> assign(:current_user, %{id: "fake"})

    conn = ElixirTestProjectWeb.Plugs.RequireAuthPlug.call(conn, %{})
    # Plug should not halt when current_user is present
    refute conn.halted
  end
end
