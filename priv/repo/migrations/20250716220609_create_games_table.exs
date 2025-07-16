defmodule Xo.Repo.Migrations.CreateGamesTable do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :string, primary_key: true
      add :player_x_id, :string, null: false
      add :player_x_name, :string, null: false
      add :player_o_id, :string
      add :player_o_name, :string
      add :current_player, :string, null: false, default: "x"
      add :board, {:array, :string}, null: false, default: []
      add :status, :string, null: false, default: "waiting_for_player"
      add :winner, :string

      timestamps()
    end

    create index(:games, [:status])
    create index(:games, [:player_x_id])
    create index(:games, [:player_o_id])
  end
end
