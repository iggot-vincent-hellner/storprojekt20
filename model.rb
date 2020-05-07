module Model

require 'bcrypt'
require 'sqlite3'
require 'byebug'


require 'securerandom'

$db = SQLite3::Database.new("db/database.db")
$db.results_as_hash = true

# Copies a file in the filesystem
#
# @param [String] source the source of the file
# @param [String] destination the destination to copy to
# @param [String] name the name of the file
def copy_with_path(src, dst, filename)
   FileUtils.mkdir_p(dst)
   FileUtils.cp(src, dst + filename)
end

# Finds user data
#
# @param [String] Email email of the user
# 
# @return [Hash]
#  * :id [Integer] The id of the user
#  * :password_digest [String] The password digest of the user
#  * :rank [Integer] rank of the user
# @return [nil] if not found
def get_user_data(email)
   $db.execute("SELECT id, password_digest, rank FROM users WHERE email=?", params[:email])
end

# Validates user password
#
# @param [Hash] data the user data
# @param [String] password the entered password
# 
# @return [Boolean] whether the the password was correct or not 
def validate_user_password(user_data, password)
   if user_data.first == nil
      false
   elsif (BCrypt::Password.new(user_data.first["password_digest"]) == password)
      true
   else
      false
   end
end

# Registers a new user
#
# @param [String] email the email of the new user
# @param [String] password the password of the new user
# @param [Integer] premium is the new user premium
def register_user(email, password, premium)
   password_digest = BCrypt::Password.create(password)
   $db.execute("INSERT INTO users (email, password_digest, rank) VALUES (?, ?, ?)", [email, password_digest, premium == "on" ? 1 : 0])
end

# Adds a new file to the database
#
# @param [String] name the name of the file
# @param [String] path the path of the file
# @param [Integer] size the size of the file
# @params [Integer] id the owner_id of the file
def add_file_to_database(name, path, size, owner)
   $db.execute("INSERT INTO files (owner_id, file_name, file_size, file_path, publicity) VALUES (?, ?, ?, ?, 0)", [owner, name, size, path])
end

# Deletes a file from the database
#
# @param [Integer] id the id of the file
def delete_file_from_database(file_id)
   $db.execute("DELETE FROM files WHERE id = ?", file_id)
   $db.execute("DELETE FROM file_share_table WHERE file_id = ?", file_id)
end

# Shares a file with a different user
#
# @param [Integer] id the id of the file to share
# @param [String] email the email of the person to share with
# 
# @return [Boolean] whether the the file was shared with a valid user or not 
def share_file(file_id, email)
   user_data = $db.execute("SELECT id FROM users WHERE email = ?", [email])[0]
   if user_data == nil
      return false
   end
   user_id = user_data["id"]
   $db.execute("INSERT INTO file_share_table (file_id, user_id) VALUES (?, ?)", [file_id, user_id])
   return true
end

# Gets the full path in the filesystem to a file
#
# @param [Integer] id the id of the file
# 
# @return [String] the path to the file 
def get_full_file_path(file_id)
   path = $db.execute("SELECT file_path FROM files WHERE id = ?", file_id)[0]["file_path"]
   return path + $db.execute("SELECT file_name FROM files WHERE id = ?", file_id)[0]["file_name"]
end

# Gets the name of a file
#
# @param [Integer] id the id of the file
# 
# @return [String] the name of the file 
def get_file_name(file_id)
   return $db.execute("SELECT file_name FROM files WHERE id = ?", file_id)[0]["file_name"]
end

# Gets the files owned by a user
#
# @param [Integer] id the id of the owner
# 
# @return [Array] the files owned my the user 
def get_owned_files(user_id)
   return $db.execute("SELECT * FROM files WHERE owner_id = ?", user_id)
end

# Gets all the files that are public
# 
# @return [Array] all public files 
def get_all_public_files()
   return $db.execute("SELECT * FROM files WHERE publicity = 1")
end

# Gets all the files
# 
# @return [Array] all files 
def get_all_files()
   return $db.execute("SELECT * FROM files")
end

# Gets all the files shared with a user
#
# @param [Integer] id the id of the user 
#
# @return [Array] all files shared with the user
def get_shared_files(user_id)
   shared_file_ids = $db.execute("SELECT file_id FROM file_share_table WHERE user_id = ?", user_id)
   
   files = []
   shared_file_ids.each do |id|
      files << $db.execute("SELECT * FROM files WHERE id = ?", id["file_id"])[0]
   end
   return files
end

# Generates a uuid
#
# @return [String] the uuid that was generated
def generate_unique_url()
   return SecureRandom.uuid 
end

# Makes a file publc
#
# @param [Integer] id the id of the file
def make_public(file_id)
   $db.execute("UPDATE files SET publicity = 1 WHERE id = ?", [file_id])
end

# Makes a file private
#
# @param [Integer] id the id of the file
def make_private(file_id)
   $db.execute("UPDATE files SET publicity = 0 WHERE id = ?", [file_id])
end

# Gets the uuid of a file or generates one if it doesnt have one
#
# @param [Integer] id the id of the file
#
# @return [String] the uuid
def get_file_unique_url(file_id)
   url = $db.execute("SELECT unique_url FROM files WHERE id = ?", file_id)[0]["unique_url"]
   if url == nil
      url = generate_unique_url();
      $db.execute("UPDATE files SET unique_url = ? WHERE id = ?", [url, file_id])[0]
   end
   return url
end

# Gets the file with a certain uuid
#
# @param [String] uuid the uuid 
#
# @return [Hash] the file with the uuid
def get_file_from_url(url)
   return $db.execute("SELECT * FROM files WHERE unique_url = ?", url)[0]
end

# Gets the rank of a user
#
# @param [Integer] id the id of the user 
#
# @return [Integer] the rank of the user
def get_user_rank(user_id)
   return $db.execute("SELECT rank FROM users WHERE id = ?", user_id)[0]["rank"]
end
end