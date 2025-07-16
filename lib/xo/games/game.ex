defmodule Xo.Games.Game do
  @moduledoc """
  Represents the state of an XO (Tic-Tac-Toe) game.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key {:id, :string, autogenerate: false}
  schema "games" do
    field :player_x_id, :string
    field :player_x_name, :string
    field :player_o_id, :string
    field :player_o_name, :string
    field :current_player, :string, default: "x"
    field :board, {:array, :string}, default: []
    field :status, :string, default: "waiting_for_player"
    field :winner, :string

    timestamps()
  end

  @type player :: %{id: String.t(), name: String.t()}
  @type board_cell :: :x | :o | nil
  @type game_status :: :waiting_for_player | :active | :finished | :draw
  @type player_symbol :: :x | :o

  @doc """
  Creates a changeset for a new game.
  """
  def changeset(game, attrs) do
    # Normalize board if provided
    normalized_attrs = 
      case Map.get(attrs, :board) do
        board when is_list(board) ->
          normalized_board = 
            if Enum.count(board) == 9 do
              board
            else
              List.duplicate("", 9)
            end
          Map.put(attrs, :board, normalized_board)
        _ -> 
          attrs
      end
    
    game
    |> cast(normalized_attrs, [:id, :player_x_id, :player_x_name, :player_o_id, :player_o_name, 
                    :current_player, :board, :status, :winner])
    |> validate_required([:id, :player_x_id, :player_x_name])
    |> validate_inclusion(:status, ["waiting_for_player", "active", "finished", "draw"])
    |> validate_inclusion(:current_player, ["x", "o"])
    # Removed strict board length validation - we handle this in normalization
  end

  @doc """
  Returns the player struct for the given symbol.
  """
  def get_player(%__MODULE__{} = game, "x"), do: %{id: game.player_x_id, name: game.player_x_name}
  def get_player(%__MODULE__{} = game, :x), do: %{id: game.player_x_id, name: game.player_x_name}
  def get_player(%__MODULE__{} = game, "o") when not is_nil(game.player_o_id), 
    do: %{id: game.player_o_id, name: game.player_o_name}
  def get_player(%__MODULE__{} = game, :o) when not is_nil(game.player_o_id), 
    do: %{id: game.player_o_id, name: game.player_o_name}
  def get_player(%__MODULE__{}, _), do: nil

  @doc """
  Returns true if the game is full (has both players).
  """
  def full?(%__MODULE__{player_x_id: x_id, player_o_id: o_id}) do
    x_id != nil and o_id != nil
  end

  @doc """
  Returns true if the game is finished (has a winner or is a draw).
  """
  def finished?(%__MODULE__{status: status}) do
    status in ["finished", "draw"]
  end

  @doc """
  Returns true if it's the given player's turn.
  """
  def player_turn?(%__MODULE__{} = game, player_id) do
    current_player = get_player(game, game.current_player)
    current_player && current_player.id == player_id
  end

  @doc """
  Converts the board array to symbols for game logic.
  """
  def board_as_symbols(%__MODULE__{board: board}) do
    # Normalize board length while preserving existing moves
    normalized_board = 
      case board do
                 nil -> 
           List.duplicate(nil, 9)
         board when is_list(board) ->
           current_length = Enum.count(board)
           cond do
             current_length == 9 -> board
             current_length < 9 -> board ++ List.duplicate(nil, 9 - current_length)
             current_length > 9 -> Enum.take(board, 9)
           end
         _ -> 
           List.duplicate(nil, 9)
      end
    
    Enum.map(normalized_board, fn
      "x" -> :x
      "o" -> :o
      nil -> nil
      "" -> nil  # Handle legacy empty strings
      _ -> nil   # Handle any unexpected values
    end)
  end

  @doc """
  Returns a display-friendly representation of the board.
  """
  def display_board(%__MODULE__{} = game) do
    game
    |> board_as_symbols()
    |> Enum.chunk_every(3)
    |> Enum.map(fn row ->
      Enum.map(row, fn
        nil -> " "
        :x -> "X"
        :o -> "O"
      end)
    end)
  end

  @doc """
  Returns the opposite player symbol.
  """
  def other_player("x"), do: "o"
  def other_player("o"), do: "x"
  def other_player(:x), do: :o
  def other_player(:o), do: :x
end 