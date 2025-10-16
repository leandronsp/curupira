defmodule CurupiraWeb.Router do
  use CurupiraWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CurupiraWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CurupiraWeb do
    pipe_through :browser

    live "/", ArticleLive.Index, :index
    live "/articles", ArticleLive.Index, :index
    live "/articles/new", ArticleLive.Form, :new
    live "/articles/:id/edit", ArticleLive.Form, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", CurupiraWeb do
  #   pipe_through :api
  # end
end
