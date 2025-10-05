# ElixirTestProject

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Reset local development DB

If you changed primary key types or migrations and want to recreate the local SQLite dev DB, use the included Mix task (destructive):

```cmd
mix reset.dev_db
```

This deletes `elixir_test_project_dev.db` (and its -shm/-wal files), runs `mix ecto.create` and `mix ecto.migrate`. Only run it in development — it is destructive.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
