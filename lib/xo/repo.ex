defmodule Xo.Repo do
  use Ecto.Repo,
    otp_app: :xo,
    adapter: Ecto.Adapters.Postgres
end
