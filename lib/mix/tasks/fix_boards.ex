defmodule Mix.Tasks.FixBoards do
  @moduledoc """
  Mix task to fix games with empty boards.
  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("Fixing games with empty boards...")
    Xo.Games.fix_empty_boards()
    IO.puts("Done!")
  end
end 