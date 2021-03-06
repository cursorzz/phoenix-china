defmodule PhoenixChina.CommentController do
  use PhoenixChina.Web, :controller

  alias PhoenixChina.{
    Comment, 
    Post, 
    Notification,
  }

  import PhoenixChina.Ecto.Helpers, only: [increment: 2, update_field: 3]

  plug Guardian.Plug.EnsureAuthenticated, [handler: PhoenixChina.Guardian.ErrorHandler]
    when action in [:create, :edit, :update, :delete]

  def show(conn, %{"post_id" => post_id, "id" => comment_id}) do
    post = 
      Post
      |> preload([:user, :latest_comment, latest_comment: :user])
      |> Repo.get!(post_id)

    comment = 
      Comment
      |> preload(:user)
      |> Repo.get!(comment_id)

    conn
    |> assign(:title, comment.user.nickname <> "在帖子" <> post.title <> "的评论")
    |> assign(:post, post)
    |> assign(:comment, comment)
    |> render("show.html")
  end

  def create(conn, %{"post_id" => post_id, "comment" => comment_params}) do
    post = 
      Repo.get! Post, post_id
    
    struct = 
      build_assoc post, :comments, 
        user_id: conn.assigns[:current_user].id, 
        index: post.comment_count + 1
    
    changeset = Comment.changeset(struct, comment_params)

    case Repo.insert(changeset) do
      {:ok, comment} ->
        post
        |> update_field(:latest_comment_id, comment.id)
        |> update_field(:latest_comment_inserted_at, comment.inserted_at)
        |> increment(:comment_count)

        Notification.create(conn, comment)

        conn |> put_flash(:info, "评论创建成功.")

      {:error, _changeset} ->
        conn |> put_flash(:error, "评论创建失败, 评论不能超过1000字.")
    end
    |> redirect(to: post_path(conn, :show, post_id))
  end

  def edit(conn, %{"post_id" => post_id, "id" => id}) do
    post = 
      Repo.get! Post, post_id
    
    comment =
      post
      |> assoc(:comments)
      |> where(user_id: ^conn.assigns[:current_user].id)
      |> Repo.get!(id)

    changeset = Comment.changeset(comment)

    conn
    |> assign(:title, "编辑评论")
    |> assign(:comment, comment)
    |> assign(:changeset, changeset)
    |> render("edit.html")
  end

  def update(conn, %{"post_id" => post_id, "id" => id, "comment" => comment_params}) do
    post = 
      Repo.get! Post, post_id
    
    comment =
      post
      |> assoc(:comments)
      |> where(user_id: ^conn.assigns[:current_user].id)
      |> Repo.get!(id)

    changeset = Comment.changeset(comment, comment_params)

    case Repo.update(changeset) do
      {:ok, _comment} ->
        conn
        |> put_flash(:info, "评论更新成功！")
        |> redirect(to: post_path(conn, :show, post_id))

      {:error, changeset} ->
        conn
        |> assign(:title, "编辑评论")
        |> assign(:comment, comment)
        |> assign(:changeset, changeset)
        |> render("edit.html")
    end
  end

  def delete(conn, %{"post_id" => post_id, "id" => id}) do
    post = 
      Repo.get! Post, post_id
    
    comment =
      post
      |> assoc(:comments)
      |> where(user_id: ^conn.assigns[:current_user].id)
      |> Repo.get!(id)

    latest_comment_id = 
      Comment
      |> where([c], c.post_id == ^comment.post_id and c.id != ^comment.id)
      |> select([u], max(u.id))
      |> Repo.one
    
    post 
    |> update_field(:latest_comment_id, latest_comment_id)

    comment 
    |> update_field(:is_deleted, true)

    conn
    |> put_flash(:info, "评论删除成功！")
    |> redirect(to: post_path(conn, :show, post_id))
  end
end
