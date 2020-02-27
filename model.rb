require 'bcrypt'
require 'sqlite3'
require 'byebug'

def db()
    db = SQLite3::Database.new("db/database.db")
    db.results_as_hash = true
    db
end

def get_user_data(email)
   db.execute("SELECT id, password_digest, rank FROM users WHERE email=?", params[:email])
end

def validate_user_password(user_data, password)
    if(BCrypt::Password.new(user_data.first["password_digest"]) == password)
        true
    else
        false
    end
end

def register_user(email, password)
    password_digest = BCrypt::Password.create(password)
    db.execute("INSERT INTO users (email, password_digest, rank) VALUES (?, ?, ?)", [email, password_digest, 0])
end

def add_file_to_database(name, path, size, owner)
    db.execute("INSERT INTO files (owner_id, file_name, file_size, file_path, publicity) VALUES (?, ?, ?, ?, 0)", [owner, name, size, path])
end

def delete_file_from_database(owner, name)
    db.execute("DELETE FROM files WHERE owner_id = ? AND file_path = ? AND file_name = ?", [owner, "./filesystem/#{owner}/", name])
end

def share_file(filename, email, owner)
    file_id = db.execute("SELECT id FROM files WHERE file_name = ? AND file_path = ?", [filename, "./filesystem/#{owner}/"]) #TODO: gör mega request istället
    user_id = db.execute("SELECT id FROM users WHERE email = ?", [email])
    db.execute("INSERT INTO file_share_table VALUES (?, ?)", [file_id, user_id])
end