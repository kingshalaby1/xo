defmodule XoWeb.GameLive.Index do
  use XoWeb, :live_view

  alias Xo.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Games.subscribe_to_lobby()
    end

    waiting_games = Games.list_waiting_games()
    
    socket = 
      socket
      |> assign(:waiting_games, waiting_games)
      |> assign(:player_name, "")
      |> assign(:error_message, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "XO Game Lobby")
  end

  @impl true
  def handle_event("create_game", %{"player_name" => player_name}, socket) do
    player_name = String.trim(player_name)
    
    if player_name != "" do
      player_id = generate_player_id()
      
      {:ok, game} = Games.create_game(player_id, player_name)
      {:noreply, 
       socket
       |> put_flash(:info, "Game created! Waiting for another player...")
       |> push_navigate(to: ~p"/games/#{game.id}?player=x")}
    else
      {:noreply, assign(socket, :error_message, "Please enter your name")}
    end
  end

  @impl true
  def handle_event("join_game", %{"game_id" => game_id, "player_name" => player_name}, socket) do
    player_name = String.trim(player_name)
    
    if player_name != "" do
      player_id = generate_player_id()
      
      case Games.join_game(game_id, player_id, player_name) do
        {:ok, _game} ->
          {:noreply, 
           socket
           |> put_flash(:info, "Joined game!")
           |> push_navigate(to: ~p"/games/#{game_id}?player=o")}
        
        {:error, :game_full} ->
          {:noreply, assign(socket, :error_message, "Game is full")}
        
        {:error, :game_not_found} ->
          {:noreply, assign(socket, :error_message, "Game not found")}
        
        {:error, reason} ->
          {:noreply, assign(socket, :error_message, "Failed to join game: #{reason}")}
      end
    else
      {:noreply, assign(socket, :error_message, "Please enter your name")}
    end
  end

  @impl true
  def handle_event("update_player_name", %{"player_name" => player_name}, socket) do
    {:noreply, assign(socket, :player_name, player_name)}
  end

  @impl true
  def handle_info({:game_created, game}, socket) do
    if game.status == "waiting_for_player" do
      updated_games = [game | socket.assigns.waiting_games]
      {:noreply, assign(socket, :waiting_games, updated_games)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    # Remove game from waiting list if it's no longer waiting
    if game.status != "waiting_for_player" do
      updated_games = Enum.reject(socket.assigns.waiting_games, &(&1.id == game.id))
      {:noreply, assign(socket, :waiting_games, updated_games)}
    else
      {:noreply, socket}
    end
  end

  defp generate_player_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end

  defp format_time_ago(naive_datetime) do
    # Convert NaiveDateTime to DateTime (assuming UTC)
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    seconds_ago = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      seconds_ago < 60 -> "#{seconds_ago}s ago"
      seconds_ago < 3600 -> "#{div(seconds_ago, 60)}m ago"
      true -> "#{div(seconds_ago, 3600)}h ago"
    end
  end
end 