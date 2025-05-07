defmodule DigitalblockchainWeb.Router do
  use DigitalblockchainWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DigitalblockchainWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DigitalblockchainWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/block", BlockLive
    live "/graph", GraphLive
  end

  scope "/api", DigitalblockchainWeb do
    pipe_through :api

    get "/context/:subject", ContextController, :show
    # 👈 Add this line
    get "/metrics", MetricsController, :index
  end

  if Application.compile_env(:digitalblockchain, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: DigitalblockchainWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
