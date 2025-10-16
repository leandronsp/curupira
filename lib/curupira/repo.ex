defmodule Curupira.Repo do
  use Ecto.Repo,
    otp_app: :curupira,
    adapter: Ecto.Adapters.Postgres
end
