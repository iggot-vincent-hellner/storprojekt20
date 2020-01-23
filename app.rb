require 'slim'
require 'bcrypt'
require 'sinatra'
require 'sqlite3'

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

enable :sessions

get('/') {
    slim(:index)
}

get('/login-page') {
    slim(:"login-page")
}

post('/login') {
    result = db.execute("SELECT id, password_digest, rank FROM users WHERE email=?", params[:email])

    if(BCrypt::Password.new(result.first["password_digest"]) == params[:password])
        session[:user_id] = result.first["id"]
        session[:rank] = result.first["rank"]
        redirect('/account')
    else
        redirect('/')
    end
}

post('/register') {
    password_digest = BCrypt::Password.create(params[:password])
    db.execute("INSERT INTO users (email, password_digest, rank) VALUES (?, ?, ?)", [params[:email], password_digest, 0])
    redirect('/')
}

get('/account') {
    slim(:account, locals:{id: session[:user_id], status: session[:rank]})
}