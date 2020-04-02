require 'bcrypt'
require 'sqlite3'
require 'byebug'


require 'securerandom'

#TODO function to generate unique id
#set file to publicity 1 and make a route to /file/url 
#Error handling if url does not exist

$db = SQLite3::Database.new("db/database.db")
$db.results_as_hash = true


def get_user_data(email)
   $db.execute("SELECT id, password_digest, rank FROM users WHERE email=?", params[:email])
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
   $db.execute("INSERT INTO users (email, password_digest, rank) VALUES (?, ?, ?)", [email, password_digest, 0])
end

def add_file_to_database(name, path, size, owner)
   $db.execute("INSERT INTO files (owner_id, file_name, file_size, file_path, publicity) VALUES (?, ?, ?, ?, 0)", [owner, name, size, path])
end

def delete_file_from_database(file_id)
   $db.execute("DELETE FROM files WHERE id = ?", file_id)
   $db.execute("DELETE FROM file_share_table WHERE file_id = ?", file_id)
end

def share_file(file_id, email) 
   user_id = $db.execute("SELECT id FROM users WHERE email = ?", [email])[0]["id"]
   $db.execute("INSERT INTO file_share_table (file_id, user_id) VALUES (?, ?)", [file_id, user_id])
end

def get_full_file_path(file_id)
   path = $db.execute("SELECT file_path FROM files WHERE id = ?", file_id)[0]["file_path"]
   return path + $db.execute("SELECT file_name FROM files WHERE id = ?", file_id)[0]["file_name"]
end

def get_file_name(file_id)
   return $db.execute("SELECT file_name FROM files WHERE id = ?", file_id)[0]["file_name"]
end

def get_owned_files(user_id)
   return $db.execute("SELECT * FROM files WHERE owner_id = ?", user_id)
end

def get_shared_files(user_id)
   shared_file_ids = $db.execute("SELECT file_id FROM file_share_table WHERE user_id = ?", user_id)
   
   files = []
   shared_file_ids.each do |id|
      files << $db.execute("SELECT * FROM files WHERE id = ?", id["file_id"])[0]
   end
   return files
end

def generate_unique_url()
   return SecureRandom.uuid
end

def get_file_unique_url(file_id)
   url = $db.execute("SELECT unique_url FROM files WHERE id = ?", file_id)[0]["unique_url"]
   if url == nil
      url = generate_unique_url();
      $db.execute("UPDATE files SET unique_url = ? WHERE id = ?", [url, file_id])[0]
   end
   p url
   return url
end

def get_file_from_url(url)
   return $db.execute("SELECT * FROM files WHERE unique_url = ?", url)[0]
end