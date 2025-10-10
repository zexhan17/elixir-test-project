defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller

  @google_oauth_base "https://accounts.google.com/o/oauth2/v2/auth"

  def get_google_redirect_link(conn, _params) do
    oauth_config = Application.get_env(:elixir_test_project, :google_oauth, [])
    client_id = Keyword.get(oauth_config, :client_id, "")
    redirect_uri = Keyword.get(oauth_config, :callback_url, "")
    scope = "openid email profile"

    cond do
      client_id == "" or redirect_uri == "" ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "missing_oauth_config"})

      true ->
        params = %{
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: scope,
          access_type: "offline",
          include_granted_scopes: "true",
          prompt: "consent"
        }

        # Filter out empty values and encode query
        query =
          params
          |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
          |> Enum.into(%{})
          |> URI.encode_query()

        redirect_url = "#{@google_oauth_base}?#{query}"

        json(conn, %{redirect_url: redirect_url})
    end
  end
end
