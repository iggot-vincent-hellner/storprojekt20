require 'slim'
require 'bcrypt'
require 'sinatra'
require 'sqlite3'

db = SQLite3::Database.new("db/database.db")
db.results_as_hash = true

enable :sessions

def copy_with_path(src, dst, filename)
    FileUtils.mkdir_p(dst)
    FileUtils.cp(src, dst + filename)
end

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
    list = Dir.glob("./filesystem/#{session[:user_id]}/*.*").map{|f| f.split('/').last}
    slim(:account, locals: { result:list } )
}

post('/file/upload') {
    tempfile = params[:file][:tempfile]
    filename = params[:file][:filename]
    copy_with_path(tempfile.path, "./filesystem/#{session[:user_id]}/", filename)
    redirect('/account')
}

post('/file/delete/:filename') { |filename|
    FileUtils.rm("./filesystem/#{session[:user_id]}/#{filename}")
    redirect('/account')
}

post('/file/download/:filename') { |filename|
    send_file("./filesystem/#{session[:user_id]}/#{filename}", :filename => filename, :type => 'Application/octet-stream')
}