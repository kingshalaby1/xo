defmodule XoWeb.GameLive.GameComponents do
  @moduledoc """
  Reusable components for XO game UI.
  """
  
  use Phoenix.Component
  alias Xo.Games.Game

  @doc """
  Renders a game board component.
  """
  attr :game, :map, required: true
  attr :current_user_id, :string, required: true
  attr :on_move, :string, default: "make_move"

  def game_board(assigns) do
    ~H"""
    <div class="flex justify-center">
      <div class="grid grid-cols-3 gap-2 p-4 bg-gray-100 rounded-xl shadow-lg">
        <%= for position <- 0..8 do %>
          <.game_cell 
            position={position}
            value={Enum.at(@game.board, position)}
            game={@game}
            current_user_id={@current_user_id}
            on_move={@on_move}
          />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a single game board cell.
  """
  attr :position, :integer, required: true
  attr :value, :atom
  attr :game, :map, required: true
  attr :current_user_id, :string, required: true
  attr :on_move, :string, default: "make_move"

  def game_cell(assigns) do
    ~H"""
    <button 
      phx-click={@on_move}
      phx-value-position={@position}
      class={get_cell_class(@game, @current_user_id, @position)}
      disabled={not can_make_move?(@game, @current_user_id, @position)}
    >
      <span class={get_cell_text_class(@value)}>
        <%= format_cell_value(@value) %>
      </span>
    </button>
    """
  end

  @doc """
  Renders player information component.
  """
  attr :game, :map, required: true
  attr :current_user_id, :string, required: true

  def players_info(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <!-- Player X -->
        <.player_card 
          player={@game.player_x}
          symbol={:x}
          is_current={@game.current_player == :x and @game.status == :active}
          color="blue"
        />

        <!-- Player O -->
        <%= if @game.player_o do %>
          <.player_card 
            player={@game.player_o}
            symbol={:o}
            is_current={@game.current_player == :o and @game.status == :active}
            color="red"
          />
        <% else %>
          <.waiting_player_card />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a single player card.
  """
  attr :player, :map, required: true
  attr :symbol, :atom, required: true
  attr :is_current, :boolean, default: false
  attr :color, :string, default: "blue"

  def player_card(assigns) do
    ~H"""
    <div class="flex items-center space-x-4">
      <div class={"w-12 h-12 bg-gradient-to-r from-#{@color}-500 to-#{@color}-600 rounded-full flex items-center justify-center"}>
        <span class="text-white font-bold text-xl"><%= String.upcase(to_string(@symbol)) %></span>
      </div>
      <div>
        <h3 class="text-lg font-semibold text-gray-800"><%= @player.name %></h3>
        <p class="text-sm text-gray-500">Player <%= String.upcase(to_string(@symbol)) %></p>
      </div>
      <%= if @is_current do %>
        <div class="ml-auto">
          <span class="inline-block w-3 h-3 bg-green-500 rounded-full animate-pulse"></span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a waiting player card.
  """
  def waiting_player_card(assigns) do
    ~H"""
    <div class="flex items-center space-x-4">
      <div class="w-12 h-12 bg-gray-300 rounded-full flex items-center justify-center">
        <span class="text-gray-500 font-bold text-xl">?</span>
      </div>
      <div>
        <h3 class="text-lg font-semibold text-gray-500">Waiting for player...</h3>
        <p class="text-sm text-gray-400">Player O</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders game status message.
  """
  attr :game, :map, required: true
  attr :current_user_id, :string, required: true

  def game_status(assigns) do
    ~H"""
    <div class="text-center">
      <div class={get_status_class(@game, @current_user_id) <> " text-xl"}>
        <%= get_status_message(@game, @current_user_id) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders game controls (reset, leave, etc.).
  """
  attr :game, :map, required: true
  attr :game_id, :string, required: true

  def game_controls(assigns) do
    ~H"""
    <div class="flex flex-wrap justify-center gap-4">
      <%= if @game.status in [:finished, :draw] do %>
        <button 
          phx-click="reset_game"
          class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-6 rounded-lg transition duration-200"
        >
          Play Again
        </button>
      <% end %>
      
      <button 
        phx-click="leave_game"
        class="bg-gray-600 hover:bg-gray-700 text-white font-medium py-2 px-6 rounded-lg transition duration-200"
      >
        Leave Game
      </button>
      
      <.link 
        navigate="/games"
        class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-6 rounded-lg transition duration-200"
      >
        Back to Lobby
      </.link>
    </div>
    """
  end

  @doc """
  Renders game result summary.
  """
  attr :game, :map, required: true

  def game_result(assigns) do
    ~H"""
    <%= if @game.status in [:finished, :draw] do %>
      <div class="bg-gray-50 rounded-lg p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-4 text-center">Game Over</h3>
        <div class="text-center space-y-2">
          <%= case @game.status do %>
            <% :finished -> %>
              <div class="text-2xl font-bold text-gray-800">
                🏆 <%= Game.get_player(@game, @game.winner).name %> Wins!
              </div>
              <div class="text-gray-600">
                Player <%= String.upcase(to_string(@game.winner)) %> got three in a row
              </div>
            <% :draw -> %>
              <div class="text-2xl font-bold text-gray-800">
                🤝 It's a Draw!
              </div>
              <div class="text-gray-600">
                All squares filled with no winner
              </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  # Private helper functions

  defp get_player_symbol(game, user_id) do
    cond do
      game.player_x && game.player_x.id == user_id -> :x
      game.player_o && game.player_o.id == user_id -> :o
      true -> nil
    end
  end

  defp is_current_player?(game, user_id) do
    current_player = Game.get_player(game, game.current_player)
    current_player && current_player.id == user_id
  end

  defp can_make_move?(game, user_id, position) do
    game.status == :active and
    is_current_player?(game, user_id) and
    Enum.at(game.board, position) == nil
  end

  defp get_cell_class(game, user_id, position) do
    base_class = "w-16 h-16 sm:w-20 sm:h-20 bg-white border-2 border-gray-300 rounded-lg flex items-center justify-center text-2xl font-bold transition-all duration-200"
    
    cell_value = Enum.at(game.board, position)
    
    cond do
      cell_value != nil ->
        "#{base_class} cursor-not-allowed"
      
      can_make_move?(game, user_id, position) ->
        "#{base_class} hover:bg-blue-50 hover:border-blue-400 cursor-pointer"
      
      true ->
        "#{base_class} cursor-not-allowed opacity-75"
    end
  end

  defp get_cell_text_class(value) do
    case value do
      :x -> "text-blue-600"
      :o -> "text-red-600"
      _ -> ""
    end
  end

  defp format_cell_value(nil), do: ""
  defp format_cell_value(:x), do: "X"
  defp format_cell_value(:o), do: "O"

  defp get_status_message(game, user_id) do
    player_symbol = get_player_symbol(game, user_id)
    
    case game.status do
      :waiting_for_player ->
        "Waiting for another player to join..."
      
      :active ->
        if is_current_player?(game, user_id) do
          "Your turn! Make your move."
        else
          current_player = Game.get_player(game, game.current_player)
          "#{current_player.name}'s turn"
        end
      
      :finished ->
        if game.winner == player_symbol do
          "🎉 You won!"
        else
          winner_player = Game.get_player(game, game.winner)
          "#{winner_player.name} won!"
        end
      
      :draw ->
        "It's a draw!"
    end
  end

  defp get_status_class(game, user_id) do
    case game.status do
      :active ->
        if is_current_player?(game, user_id) do
          "text-green-600 font-semibold"
        else
          "text-gray-600"
        end
      
      :finished ->
        player_symbol = get_player_symbol(game, user_id)
        if game.winner == player_symbol do
          "text-green-600 font-bold"
        else
          "text-red-600 font-bold"
        end
      
      :draw ->
        "text-yellow-600 font-bold"
      
      _ ->
        "text-gray-600"
    end
  end
end 