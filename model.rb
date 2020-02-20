require 'bcrypt'
require 'sqlite3'

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