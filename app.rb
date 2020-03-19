require 'slim'
require 'bcrypt'
require 'sinatra'
require 'sqlite3'
require 'byebug'
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
    list = Dir.glob("./filesystem/#{session[:user_id]}/*.*").map{|f| f.split('/').last} #TODO: Gör så detta sker via databasen och model.rb då kan man få id till slimen också så slipper ta fram id genom filnamn i delete och edit och liknade i model.rb
    shared = get_shared_files(session[:user_id])
    slim(:account, locals: { result:list, shared:shared } )
}

post('/file/upload') {
    tempfile = params[:file][:tempfile]
    filename = params[:file][:filename]
    copy_with_path(tempfile.path, "./filesystem/#{session[:user_id]}/", filename)

    add_file_to_database(filename, "./filesystem/#{session[:user_id]}/", -1, session[:user_id])

    redirect('/account')
}

post('/file/delete/:filename') { |filename|
    FileUtils.rm("./filesystem/#{session[:user_id]}/#{filename}")

    delete_file_from_database(session[:user_id], filename)

    redirect('/account')
}

post('/file/download/:filename') { |filename|
    send_file("./filesystem/#{session[:user_id]}/#{filename}", :filename => filename, :type => 'Application/octet-stream')
}

post('/file/share/:filename') { |filename|
    share_file(filename, params[:email], session[:user_id])
}