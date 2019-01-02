# lib/house_party/router.ex
defmodule HouseParty.Router do
  use Plug.Router
  use Plug.Debugger
  require Logger
  plug(Plug.Logger, log: :debug)
  plug(:match)
  plug(:dispatch)

  get "/hello" do
      send_resp(conn, 200, "world")
  end

  get "/scenario/small" do
    HouseParty.setup_party(:small)
    send_resp(conn, 200, tldr_body())
  end

  get "/scenario/big" do
    HouseParty.setup_party(:big)
    send_resp(conn, 200, tldr_body())
  end

  get "/stats/tldr" do
    send_resp(conn, 200, tldr_body())
  end

  # "Default" route that will get called when no other route is matched
  match _ do
    send_resp(conn, 404, "not found")
  end

  defp tldr_body() do
    """
    self: #{inspect(:erlang.node())}\nnodes: #{inspect(:erlang.nodes())}

    #{inspect(HouseParty.Stats.tldr())}
    """
  end

end
