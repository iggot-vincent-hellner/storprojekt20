require 'slim'
require 'bcrypt'
require 'sinatra'
require 'sqlite3'
require './model.rb'

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
    user_data = get_user_data(params[:email])
    if(validate_user_password(user_data, params[:password]))
        session[:user_id] = user_data.first["id"]
        session[:rank] = user_data.first["rank"]
        redirect('/account')
    else
        redirect('/')
    end
}

post('/register') {
    register_user(params[:email], params[:password])
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