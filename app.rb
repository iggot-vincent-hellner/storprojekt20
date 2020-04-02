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
    list = get_owned_files(session[:user_id])
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

post('/file/delete/:file_id') { |file_id|
    FileUtils.rm(get_full_file_path(file_id))
    delete_file_from_database(file_id)

    redirect('/account')
}

post('/file/generate_id/:file_id') { |file_id| #KOLLA OM ÄGARE
    get_file_unique_url(file_id) #Kankse ha generate funk inte get?
    redirect('/account')
}

post('/file/download/:file_id') { |file_id| #KOLLA OM MAN HAR PERMISSION ATT LADDA NER (ÄGARE, DELAD, ELLER PUBLIC (URL))
    send_file(get_full_file_path(file_id), :filename => get_file_name(file_id), :type => 'Application/octet-stream')
}

get('/file/:file_url') { |file_url|
    slim(:"files/index", locals: {file:get_file_from_url(file_url)})
}

post('/file/share/:file_id') { |file_id|
    share_file(file_id, params[:email])
    redirect('/account')
}