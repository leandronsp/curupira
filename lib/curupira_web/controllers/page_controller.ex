defmodule CurupiraWeb.PageController do
  use CurupiraWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
