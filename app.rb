require 'google/cloud/storage'
require 'sinatra'
require 'digest'
require 'json'

# Google Cloud Storage setup
storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

# -------------------------------
# Helper Functions
# -------------------------------
def valid_digest(digest)
  return params['digest'].length == 64 && params['digest'] =~ /^[A-F0-9]+$/i
end

def path_from_digest(digest)
  return (digest[0..1] + '/' + digest[2..3] + '/' + digest[4..-1]).downcase
end

# -------------------------------
# GET
# -------------------------------
get '/' do
  redirect to('/files/'), 302
end

get '/files/' do
  content_type :json
  bucket.files.map {|file| file.name.gsub!('/', '') if file.name.length == 66 && file.name[2] == '/' && file.name[5] == '/'}.compact.sort.to_json
end

get '/files/:digest' do

  # Handle malformed digest
  if !valid_digest(params['digest'])
    return 422
  end

  # Get bucket path
  bucket_path = path_from_digest(params['digest'])

  # Retrieve file
  if bucket.files.map {|file| file.name}.include? bucket_path
    file = bucket.file bucket_path
    downloaded = file.download
    downloaded.rewind
    content_type file.content_type
    return downloaded.read
  else
    return 404
  end
end

# -------------------------------
# DELETE
# -------------------------------
delete '/files/:digest' do

  # Handle malformed digest
  if !valid_digest(params['digest'])
    return 422
  end

  # Get bucket path
  bucket_path = path_from_digest(params['digest'])

  # Delete file if exists
  if bucket.files.map {|file| file.name}.include? bucket_path
    file = bucket.file bucket_path
    file.delete
  end

  return 200
end

# -------------------------------
# POST
# -------------------------------
post '/files/' do

  # Make sure file size is ok
  begin
    fsize = File.size(params['file']['tempfile'])
  rescue
    return 422
  end

  if !(fsize > 0 && fsize <= 2 ** 20)
    return 422
  end

  # Get bucket path
  digest = Digest::SHA256.hexdigest File.read(params['file']['tempfile'])
  bucket_path = path_from_digest(digest)

  # Check if exists
  if bucket.files.map {|file| file.name}.include? bucket_path
    return 409
  else
    file = bucket.create_file(params['file']['tempfile'], bucket_path, content_type: params['file']['type'])
  end

  content_type :json
  status 201
  return { "uploaded" => digest }.to_json
end
