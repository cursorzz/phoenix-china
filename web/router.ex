defmodule PhoenixChina.Router do
  use PhoenixChina.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :browser_session do
    plug Guardian.Plug.VerifySession
    plug Guardian.Plug.LoadResource
    plug PhoenixChina.Guardian.CurrentUser
  end

  pipeline :admin_browser_session do
    plug Guardian.Plug.VerifySession, key: :admin
    plug PhoenixChina.Guardian.CurrentUser, key: :admin
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Guardian.Plug.VerifyHeader
    plug Guardian.Plug.LoadResource
  end

  scope "/", PhoenixChina do
    pipe_through [:browser, :browser_session, :admin_browser_session]

    get "/", PageController, :index
    get "/last", PageController, :last
    get "/noreply", PageController, :noreply
    get "/signup", UserController, :new
    post "/signup", UserController, :create
    get "/signin", SessionController, :new
    post "/signin", SessionController, :create
    get "/signout", SessionController, :delete

    resources "/password_reset", PasswordResetController, only: [:create, :show, :update], singleton: true

    resources "/posts", PostController do
       resources "/comments", CommentController, except: [:index]

       resources "/praise", PostPraiseController, as: :praise, only: [:create, :delete], singleton: true
       resources "/collect", PostCollectController, as: :collect, only: [:create, :delete], singleton: true

       put "/set_top", PostController, :set_top
       put "/cancel_top", PostController, :cancel_top
    end

    resources "/comments", CommentController, only: [] do
      resources "/praise", CommentPraiseController, as: :praise, only: [:create, :delete], singleton: true
    end

    resources "/users", UserController, param: "username", only: [:show] do
      resources "/follow", UserFollowController, as: :follow, only: [:create, :delete], singleton: true
    end

    resources "/settings/:page", UserController, only: [:edit, :update], singleton: true
    resources "/notifications", NotificationController, only: [:index]
  end

  scope "/auth", PhoenixChina do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  # Other scopes may use custom stacks.
  scope "/api/v1", PhoenixChina do
    pipe_through :api

    post "/upload", API.V1.UploadController, :create
  end


end
