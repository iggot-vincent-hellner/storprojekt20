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

before do
    if (session[:user_id] == nil) && (request.path_info != '/') && (request.path_info != '/register') && (request.path_info != '/login-page') && (request.path_info != '/login') && (request.path_info != '/login') && (request.path_info != '/error') && (!request.path_info.start_with?('/file')) 
        session[:error] = "You need to log in to see this"
        redirect('/error')
    end
end

get('/error') {
    slim(:error, locals: {error: session[:error]})
}

get('/') {
    slim(:index)
}

before '/login-page' do
    if session[:incorrect_attempts] != nil && session[:incorrect_attempts] >= 2
        if session[:has_cooldown] == nil || session[:has_cooldown] == false
            session[:has_cooldown] = true
            session[:cooldown_start] = Time.now.to_i
        elsif Time.now.to_i - session[:cooldown_start] >= 20
            session[:has_cooldown] = false
            session[:incorrect_attempts] = 0
        else
            session[:error] = "You have to wait #{20 - (Time.now.to_i - session[:cooldown_start])} seconds"
            redirect('/error')
        end
    end
end

get('/login-page') { #TODO ändra till "/login"
    slim(:"login-page")
}

post('/login') {
    user_data = get_user_data(params[:email])
    if(validate_user_password(user_data, params[:password]))
        session[:user_id] = user_data.first["id"]
        session[:rank] = user_data.first["rank"]
        redirect('/account')
    else
        if session[:incorrect_attempts] == nil
            session[:incorrect_attempts] = 1
        else
            session[:incorrect_attempts] += 1
        end

        session[:error] = "Invalid username or password"
        redirect('/error')
    end
}

post('/register') {
    if !params[:email].include?('@')
        session[:error] = "Not a valid email"
        redirect('/error')
    end
    register_user(params[:email], params[:password], params[:premium])
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

post('/file/publicise/:file_id') { |file_id| #KOLLA OM MAN HAR PERMISSION ATT LADDA NER (ÄGARE, DELAD, ELLER PUBLIC (URL))
    make_public(file_id)
    redirect('/account')
}

post('/file/privatise/:file_id') { |file_id| #KOLLA OM MAN HAR PERMISSION ATT LADDA NER (ÄGARE, DELAD, ELLER PUBLIC (URL))
    make_private(file_id)
    redirect('/account')
}

get('/file') { #Ändra till /files
    if(session[:user_id] != nil && get_user_rank(session[:user_id]) == 1)
        slim(:"files/premium_view", locals: {files:get_all_files()})
    else
        slim(:"files/all", locals: {files:get_all_public_files()})
    end
}

get('/file/:file_url') { |file_url|
    slim(:"files/index", locals: {file:get_file_from_url(file_url)})
}

post('/file/share/:file_id') { |file_id|
    share_file(file_id, params[:email])
    redirect('/account')
}