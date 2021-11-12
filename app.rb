require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require 'pg'
enable :sessions

client = PG::connect(
    :host => "localhost",
    :user => ENV.fetch("USER", "ryouto715"), :password => '',
    :dbname => "myapp")

get "/top" do
    return erb :top
end

get '/signup' do
    return erb :signup
end

post '/signup' do
    name = params[:name]
    email = params[:email]
    password = params[:password]
    client.exec_params(
        "INSERT INTO users (name, email, password) VALUES ($1, $2, $3)",
        [name, email, password]
    )
    user = client.exec_params(
        "SELECT * from users WHERE email = $1 AND password = $2 LIMIT 1",
        [email, password]
    ).to_a.first

    session[:user] = user
    return redirect '/top'
end

get "/login" do
    return erb :login
end

post '/login' do
    name = params[:name]
    password = params[:password]
    user = client.exec_params(
        "SELECT * FROM users WHERE name = $1 AND password = $2 LIMIT 1",
        [name, password]
    ).to_a.first
    if user.nil?
        return erb :login
    else
        session[:user] = user
        return redirect "/top"
    end
end

delete '/logout' do
    session[:user] =nil
    return redirect 'login'
end

get "/new_post" do
    if session[:user].nil?
        return redirect '/login'
    end
    return erb :new_post
end

post "/new_post" do
    title = params[:title]
    content = params[:content]
    user = session[:user]

    if !params[:post_header_image].nil? # データがあれば処理を続行する
        tempfile = params[:post_header_image][:tempfile] # ファイルがアップロードされた場所
        save_to = "./public/images/#{params[:post_header_image][:filename]}" # ファイルを保存したい場所
        FileUtils.mv(tempfile, save_to)
        post_header_image_path = params[:post_header_image][:filename]
    end

    if !params[:images].nil? # データがあれば処理を続行する
        images = params[:images]
        image_path =[]
        images.each do |image|
            tempfile = image[:tempfile] # ファイルがアップロードされた場所
            save_to = "./public/images/#{image[:filename]}" # ファイルを保存したい場所
            FileUtils.mv(tempfile, save_to)
            image_path.push(image[:filename])
        end
    end

    post = client.exec_params(
        "INSERT INTO posts (title, content, post_header_image_path, user_id) VALUES ($1, $2, $3, $4) returning *",
        [title, content, post_header_image_path, user['id']]
    ).to_a.first

    if !params[:images].nil?
        image_path.each do |path|
            client.exec_params(
                "INSERT INTO images (post_id, path) VALUES ($1, $2)",
                [post['id'], path]
            )
        end
    end
    redirect '/posts'
end

get '/posts' do
    @posts = client.exec_params("SELECT * FROM posts").to_a
    @posts.each do |post|
        imagesArr = []
        images = client.exec_params("SELECT * FROM images WHERE post_id = $1;", [post['id']]).to_a
        images.each do |image|
            imagesArr.push(image['path'])
        end
        post['image_path'] = imagesArr
    end
    return erb :posts
end

get '/mypage' do
    if session[:user].nil?
        return redirect '/login'
    end
    @name = session[:user]['name']
    @profile = client.exec_params("SELECT profile, profile_image FROM users WHERE id = $1;", [session[:user]['id']]).to_a
    @myposts = client.exec_params("SELECT * FROM posts WHERE user_id = $1;", [session[:user]['id']]).to_a
    return erb :mypage
end

get '/edit_profile' do
    @profile = client.exec_params("SELECT profile, profile_image FROM users WHERE id = $1;", [session[:user]['id']]).to_a
    return erb :edit_profile
end

post '/edit_profile' do
    user = session[:user]
    profile = params[:profile]

    if !params[:profile_image].nil? # データがあれば処理を続行する
        tempfile = params[:profile_image][:tempfile] # ファイルがアップロードされた場所
        save_to = "./public/images/#{params[:profile_image][:filename]}" # ファイルを保存したい場所
        FileUtils.mv(tempfile, save_to)
        profile_image = params[:profile_image][:filename]
    end

    client.exec_params(
        "UPDATE users SET profile = $1, profile_image = $2 WHERE id = $3;",
        [profile, profile_image, user['id']]
    )
    redirect '/mypage'
end

post '/delete/:id' do
    client.exec_params("DELETE FROM posts WHERE id = $1;", [params['id']])
    redirect '/mypage'
end

# post '/search' do
#     keyword = params[:keyword]
#     @search = client.exec_params("SELECT * FROM posts where title = '$1';", [keyword]).to_a
#     redirect '/posts'
# end