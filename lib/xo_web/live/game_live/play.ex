defmodule XoWeb.GameLive.Play do
  use XoWeb, :live_view

  alias Xo.Games
  alias Xo.Games.Game

  @impl true
  def mount(%{"game_id" => game_id}, session, socket) do
    if connected?(socket) do
      Games.subscribe_to_game(game_id)
    end

    case Games.get_game(game_id) do
      {:ok, game} ->
        # Get user ID from session or URL params, with game context
        current_user_id = get_current_user_id(session, socket, game)
        
        socket = 
          socket
          |> assign(:game, game)
          |> assign(:game_id, game_id)
          |> assign(:current_user_id, current_user_id)
          |> assign(:error_message, nil)

        {:ok, socket}
      
      {:error, :game_not_found} ->
        socket = 
          socket
          |> put_flash(:error, "Game not found")
          |> push_navigate(to: ~p"/games")

        {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Update user ID if player param is provided
    socket = case params do
      %{"player" => "x"} ->
        game = socket.assigns.game
        assign(socket, :current_user_id, game.player_x_id)
      
      %{"player" => "o"} ->
        game = socket.assigns.game
        assign(socket, :current_user_id, game.player_o_id)
      
      %{"user_id" => user_id} ->
        assign(socket, :current_user_id, user_id)
      
      _ ->
        socket
    end
    
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :play, _params) do
    game = socket.assigns.game
    
    socket
    |> assign(:page_title, "XO Game - #{game.player_x_name} vs #{game.player_o_name || "Waiting..."}")
  end

  @impl true
  def handle_event("make_move", %{"position" => position}, socket) do
    game_id = socket.assigns.game_id
    user_id = socket.assigns.current_user_id
    position = String.to_integer(position)
    
    case Games.make_move(game_id, user_id, position) do
      {:ok, _updated_game} ->
        {:noreply, assign(socket, :error_message, nil)}
      
      {:error, :not_your_turn} ->
        {:noreply, assign(socket, :error_message, "It's not your turn!")}
      
      {:error, :position_taken} ->
        {:noreply, assign(socket, :error_message, "That position is already taken!")}
      
      {:error, :game_not_active} ->
        {:noreply, assign(socket, :error_message, "Game is not active")}
      
      {:error, :invalid_position} ->
        {:noreply, assign(socket, :error_message, "Invalid position")}
      
      {:error, reason} ->
        {:noreply, assign(socket, :error_message, "Error: #{reason}")}
    end
  end

  @impl true
  def handle_event("reset_game", _params, socket) do
    game_id = socket.assigns.game_id
    
    case Games.reset_game(game_id) do
      {:ok, _game} ->
        {:noreply, 
         socket
         |> assign(:error_message, nil)
         |> put_flash(:info, "Game reset!")}
      
      {:error, reason} ->
        {:noreply, assign(socket, :error_message, "Failed to reset game: #{reason}")}
    end
  end

  @impl true
  def handle_event("leave_game", _params, socket) do
    {:noreply, 
     socket
     |> put_flash(:info, "Left the game")
     |> push_navigate(to: ~p"/games")}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    {:noreply, assign(socket, :game, game)}
  end

  defp get_current_user_id(session, socket, game) do
    # Check URL params first for demo purposes
    case get_connect_params(socket) do
      %{"player" => "x"} -> 
        # User claims to be player X, return that player's ID
        game.player_x_id
      
      %{"player" => "o"} -> 
        # User claims to be player O, return that player's ID
        game.player_o_id
      
      %{"user_id" => user_id} -> 
        user_id
      
      _ -> 
        # Check session for stored user ID
        case session do
          %{"user_id" => user_id} -> user_id
          _ -> 
            # For demo: default to player X if no identification
            game.player_x_id || generate_user_id()
        end
    end
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  defp get_player_symbol(game, user_id) do
    cond do
      game.player_x_id == user_id -> :x
      game.player_o_id == user_id -> :o
      true -> nil
    end
  end

  defp is_current_player?(game, user_id) do
    current_player = Game.get_player(game, game.current_player)
    current_player && current_player.id == user_id
  end

  defp can_make_move?(game, user_id, position) do
    game.status == "active" and
    is_current_player?(game, user_id) and
    (Enum.at(game.board, position) == "" or Enum.at(game.board, position) == nil)
  end

  defp get_cell_class(game, user_id, position) do
    base_class = "w-16 h-16 sm:w-20 sm:h-20 bg-white border-2 border-gray-300 rounded-lg flex items-center justify-center text-2xl font-bold transition-all duration-200"
    
    cell_value = Enum.at(game.board, position)
    
    cond do
      cell_value != nil and cell_value != "" ->
        # Cell is taken
        "#{base_class} cursor-not-allowed"
      
      can_make_move?(game, user_id, position) ->
        # Player can make a move here
        "#{base_class} hover:bg-blue-50 hover:border-blue-400 cursor-pointer"
      
      true ->
        # Not player's turn or game not active
        "#{base_class} cursor-not-allowed opacity-75"
    end
  end

  defp format_cell_value(nil), do: ""
  defp format_cell_value(""), do: ""
  defp format_cell_value("x"), do: "X"
  defp format_cell_value("o"), do: "O"
  defp format_cell_value(:x), do: "X"
  defp format_cell_value(:o), do: "O"

  defp get_status_message(game, user_id) do
    player_symbol = get_player_symbol(game, user_id)
    
    case game.status do
      "waiting_for_player" ->
        "Waiting for another player to join..."
      
      "active" ->
        if is_current_player?(game, user_id) do
          "Your turn! Make your move."
        else
          current_player = Game.get_player(game, game.current_player)
          "#{current_player.name}'s turn"
        end
      
      "finished" ->
        winner_symbol = if game.winner == "x", do: :x, else: :o
        if winner_symbol == player_symbol do
          "🎉 You won!"
        else
          winner_player = Game.get_player(game, game.winner)
          "#{winner_player.name} won!"
        end
      
      "draw" ->
        "It's a draw!"
    end
  end

  defp get_status_class(game, user_id) do
    case game.status do
      "active" ->
        if is_current_player?(game, user_id) do
          "text-green-600 font-semibold"
        else
          "text-gray-600"
        end
      
      "finished" ->
        player_symbol = get_player_symbol(game, user_id)
        winner_symbol = if game.winner == "x", do: :x, else: :o
        if winner_symbol == player_symbol do
          "text-green-600 font-bold"
        else
          "text-red-600 font-bold"
        end
      
      "draw" ->
        "text-yellow-600 font-bold"
      
      _ ->
        "text-gray-600"
    end
  end
end 