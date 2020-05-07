require 'slim'
require 'bcrypt'
require 'sinatra'
require 'sqlite3'
require 'byebug'
require './model.rb'

include Model

enable :sessions

before do
    if (session[:user_id] == nil) && (request.path_info != '/') && (request.path_info != '/register') && (request.path_info != '/login-page') && (request.path_info != '/login') && (request.path_info != '/login') && (request.path_info != '/error') && (!request.path_info.start_with?('/file')) 
        session[:error] = "You need to log in to see this"
        redirect('/error')
    end
end

# Displays error page
#
get('/error') {
    slim(:error, locals: {error: session[:error]})
}

# Displays start page where you can register
#
get('/') {
    slim(:index)
}

before '/login' do
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

# Displays login page
#
get('/login-page') { #TODO ändra till "/login"
    slim(:"login")
}

# Logs you in or gives error based on params
#
# @param [String] :email, the email of the user
# @param [String] :password, the password of the user
#
# @see Model#validate_user_password
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

# Register you in or gives error based on if the email is valid
#
# @param [String] :email, the email of the user
# @param [String] :password, the password of the user
# @param [Integer] :premium, did the user register for premium
#
# @see Model#register_user
post('/register') {
    if !params[:email].include?('@')
        session[:error] = "Not a valid email"
        redirect('/error')
    end
    register_user(params[:email], params[:password], params[:premium])
    redirect('/')
}

# Displays the account home page where you can see and edit your files
#
# @see Model#get_owned_files
# @see Model#get_shared_files
get('/account') {
    list = get_owned_files(session[:user_id])
    shared = get_shared_files(session[:user_id])
    slim(:account, locals: { result:list, shared:shared } )
}

# Upload a new file
#
# @param [File] :file, the file to be uploaded
# @see Model#copy_with_path
# @see Model#add_file_to_database
post('/files/upload') {
    tempfile = params[:file][:tempfile]
    filename = params[:file][:filename]

    copy_with_path(tempfile.path, "./filesystem/#{session[:user_id]}/", filename)
    add_file_to_database(filename, "./filesystem/#{session[:user_id]}/", -1, session[:user_id])

    redirect('/account')
}

# Deletes a single file
#
# @param [Integer] :file_id, the file to be deleted
# @see Model#delete_from_database
# @see Model#get_full_path
post('/files/delete/:file_id') { |file_id|
    FileUtils.rm(get_full_file_path(file_id))
    delete_file_from_database(file_id)

    redirect('/account')
}

# Generates unique url-id for single file
#
# @param [Integer] :file_id, the file to be generated for
# @see Model#get_file_unique_id
post('/files/generate_id/:file_id') { |file_id|
    get_file_unique_url(file_id) 
    redirect('/account')
}

# Downloads a single file
#
# @param [Integer] :file_id, the file to be downloaded
post('/files/download/:file_id') { |file_id| 
    send_file(get_full_file_path(file_id), :filename => get_file_name(file_id), :type => 'Application/octet-stream')
}

# Plublicises a single file
#
# @param [Integer] :file_id, the file to be publicised
# @see Model#make_public
post('/files/publicise/:file_id') { |file_id| 
    make_public(file_id)
    redirect('/account')
}

# Privatises a single file
#
# @param [Integer] :file_id, the file to be privatised
# @see Model#make_private
post('/files/privatise/:file_id') { |file_id|
    make_private(file_id)
    redirect('/account')
}

# Displays all pubic files or all files if user is premium
#
# @see Model#get_all_files
# @see Model#get_all_public_files
get('/files') {
    if(session[:user_id] != nil && get_user_rank(session[:user_id]) == 1)
        slim(:"files/premium_view", locals: {files:get_all_files()})
    else
        slim(:"files/index", locals: {files:get_all_public_files()})
    end
}

# Displays a single file based on url-id
#
# @param [String] :file_url, the unique url-id for the file to be displayed
# @see Model#get_file_from_url
get('/files/:file_url') { |file_url|
    slim(:"files/show", locals: {file:get_file_from_url(file_url)})
}

# Shares a single file
#
# @param [Integer] :file_id, the file to be shared
# @see Model#share_file
post('/files/share/:file_id') { |file_id|
    success = share_file(file_id, params[:email])
    if(!success)
        session[:error] = "Not a valid user"
        redirect('/error')
    end
    redirect('/account')
}