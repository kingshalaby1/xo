defmodule Xo.Games do
  @moduledoc """
  The Games context for managing XO (Tic-Tac-Toe) multiplayer games.
  """

  import Ecto.Query, warn: false
  alias Xo.Repo
  alias Phoenix.PubSub
  alias Xo.Games.Game

  @pubsub Xo.PubSub

  # Game management functions

  @doc """
  Creates a new game with the given player as player X.
  """
  def create_game(player_id, player_name) do
    game_id = generate_game_id()
    
    attrs = %{
      id: game_id,
      player_x_id: player_id,
      player_x_name: player_name,
      current_player: "x",
      board: initialize_board(),
      status: "waiting_for_player"
    }

    game = %Game{}
    |> Game.changeset(attrs)
    |> Repo.insert()
    
    case game do
      {:ok, game} ->
        broadcast_game_created(game)
        {:ok, game}
      error -> error
    end
  end

  @doc """
  Joins an existing game as player O.
  """
  def join_game(game_id, player_id, player_name) do
    case get_game(game_id) do
      {:ok, game} when game.status == "waiting_for_player" and is_nil(game.player_o_id) ->
        attrs = %{
          player_o_id: player_id,
          player_o_name: player_name,
          status: "active"
        }
        
        updated_game = 
          game
          |> Game.changeset(attrs)
          |> Repo.update()
        
        case updated_game do
          {:ok, game} ->
            broadcast_game_updated(game)
            {:ok, game}
          error -> error
        end
      
      {:ok, _game} ->
        {:error, :game_full}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Makes a move on the game board.
  """
  def make_move(game_id, player_id, position) do
    IO.puts("MOVE: Player #{player_id} wants to move to position #{position}")
    
    with {:ok, game} <- get_game(game_id),
         {:ok, player_symbol} <- validate_player_turn(game, player_id) do
      
      case make_move_on_board(Game.board_as_symbols(game), position, player_symbol) do
        {:ok, updated_board} ->
          winner = check_winner(updated_board)
          status = determine_game_status(updated_board, winner)
          next_player = if status == "active", do: toggle_player(game.current_player), else: game.current_player
          
          # Convert symbols back to strings for database storage
          # Use null instead of empty strings to preserve positions
          board_strings = Enum.map(updated_board, fn
            :x -> "x"
            :o -> "o"
            nil -> nil
          end)
          
          attrs = %{
            board: board_strings,
            current_player: next_player,
            status: status,
            winner: winner && to_string(winner)
          }
          
          updated_game = 
            game
            |> Game.changeset(attrs)
            |> Repo.update()
          
          case updated_game do
            {:ok, game} ->
              broadcast_game_updated(game)
              {:ok, game}
            {:error, changeset} -> 
              {:error, "Validation failed: #{inspect(changeset.errors)}"}
          end
        
        error -> error
      end
    else
      error -> error
    end
  end

  @doc """
  Gets the current state of a game.
  """
  def get_game(game_id) do
    case Repo.get(Game, game_id) do
      nil -> {:error, :game_not_found}
      game -> {:ok, game}
    end
  end

  @doc """
  Lists all active games waiting for players.
  """
  def list_waiting_games do
    from(g in Game,
      where: g.status == "waiting_for_player",
      order_by: [desc: g.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Subscribes to game updates for a specific game.
  """
  def subscribe_to_game(game_id) do
    PubSub.subscribe(@pubsub, "game:#{game_id}")
  end

  @doc """
  Subscribes to lobby updates (new games created).
  """
  def subscribe_to_lobby do
    PubSub.subscribe(@pubsub, "lobby")
  end

  @doc """
  Fixes games with empty boards by setting them to proper 9-element arrays.
  """
  def fix_empty_boards do
    from(g in Game, where: fragment("array_length(?, 1) IS NULL OR array_length(?, 1) != 9", g.board, g.board))
    |> Repo.all()
    |> Enum.each(fn game ->
      game
      |> Game.changeset(%{board: List.duplicate("", 9)})
      |> Repo.update()
    end)
  end

  @doc """
  Resets a game to initial state (for rematch).
  """
  def reset_game(game_id) do
    with {:ok, game} <- get_game(game_id) do
      attrs = %{
        board: initialize_board(),
        current_player: "x",
        status: "active",
        winner: nil
      }
      
      updated_game = 
        game
        |> Game.changeset(attrs)
        |> Repo.update()
      
      case updated_game do
        {:ok, game} ->
          broadcast_game_updated(game)
          {:ok, game}
        error -> error
      end
    end
  end

  # Private functions

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  defp initialize_board do
    List.duplicate(nil, 9)
  end

  defp validate_player_turn(game, player_id) do
    cond do
      game.status != "active" ->
        {:error, :game_not_active}
      
      game.current_player == "x" and game.player_x_id == player_id ->
        {:ok, :x}
      
      game.current_player == "o" and game.player_o_id == player_id ->
        {:ok, :o}
      
      true ->
        {:error, :not_your_turn}
    end
  end

  defp make_move_on_board(board, position, symbol) do
    IO.puts("BOARD_MOVE: Placing #{symbol} at position #{position}")
    IO.puts("BOARD_BEFORE: #{inspect(board)}")
    
    # Ensure we have exactly 9 elements while preserving moves
    normalized_board = 
      case board do
        board when is_list(board) ->
          current_length = Enum.count(board)
          cond do
            current_length == 9 -> board
            current_length < 9 -> 
              IO.puts("WARNING: Board length #{current_length}, extending to 9")
              board ++ List.duplicate(nil, 9 - current_length)
            current_length > 9 -> 
              IO.puts("WARNING: Board length #{current_length}, trimming to 9") 
              Enum.take(board, 9)
          end
        _ -> 
          IO.puts("WARNING: Invalid board, creating new one")
          List.duplicate(nil, 9)
      end
    
    cell_value = Enum.at(normalized_board, position)
    IO.puts("CELL_CHECK: Position #{position} contains #{inspect(cell_value)}")
    
    cond do
      position < 0 or position > 8 ->
        {:error, :invalid_position}
      
      cell_value != nil ->
        IO.puts("ERROR: Position #{position} is already taken!")
        {:error, :position_taken}
      
      true ->
        updated_board = List.replace_at(normalized_board, position, symbol)
        IO.puts("BOARD_AFTER: #{inspect(updated_board)}")
        {:ok, updated_board}
    end
  end

  defp check_winner(board) do
    winning_combinations = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], # rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], # columns
      [0, 4, 8], [2, 4, 6]             # diagonals
    ]

    Enum.find_value(winning_combinations, fn [a, b, c] ->
      case {Enum.at(board, a), Enum.at(board, b), Enum.at(board, c)} do
        {symbol, symbol, symbol} when symbol != nil -> symbol
        _ -> nil
      end
    end)
  end

  defp determine_game_status(board, winner) do
    cond do
      winner != nil -> "finished"
      Enum.count(board) == 9 and Enum.all?(board, & &1 != nil) -> "draw"
      true -> "active"
    end
  end

  defp toggle_player("x"), do: "o"
  defp toggle_player("o"), do: "x"

  defp broadcast_game_created(game) do
    PubSub.broadcast(@pubsub, "lobby", {:game_created, game})
  end

  defp broadcast_game_updated(game) do
    PubSub.broadcast(@pubsub, "game:#{game.id}", {:game_updated, game})
  end
end 