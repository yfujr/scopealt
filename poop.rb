require 'net/http'
require 'json'
require 'zlib'
require 'stringio'

POSSIBLE_CHARACTERS = [*?a..?z] + [*?0..?9] + ["_"]
ROBLO_SECURITY = "" # necessary for ROBLOX to allow you to query

$success_list = [] # Global list of successful usernames

# Trap Ctrl+C (SIGINT) to print successful usernames
trap("INT") do
  puts "\n\n=== INTERRUPTED! SUCCESSFUL USERNAMES FOUND SO FAR: ==="
  puts $success_list.join("\n")
  puts "Total successes: #{$success_list.size}"
  exit
end

def valid_username?(username)
  url = URI.parse("https://auth.roblox.com/v1/usernames/validate?context=UsernameChange&username=#{username}")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  req = Net::HTTP::Get.new(url.request_uri)
  req["Accept-Encoding"] = "gzip, deflate, br"
  req["Cookie"] = ".ROBLOSECURITY=#{ROBLO_SECURITY}"

  begin
    response = http.request(req)
  rescue
    retry
  end

  body = response.body
  if response['Content-Encoding'] == 'gzip'
    body = Zlib::GzipReader.new(StringIO.new(body)).read
  end

  JSON.parse(body)['data'] == 0
end

def operation(word, i, success_f, fail_f)
  if valid_username?(word)
    puts "------ #{i}: #{word}"
    success_f.write(word + "\n")
    $success_list << word
  else
    puts "#{i}: #{word} failed"
    fail_f.write(word + "\n")
  end
end

def alphanumeric_permutations(input, length, current_str)
  return [ current_str ] if current_str.length == length
  ret = []
  for i in (0...input.length) do
    at_str_end = (current_str.length == 0) || (current_str.length + 1 == length)
    has_underscore = current_str.include?("_")
    next if ((at_str_end || has_underscore) && input[i] == '_')
    ret.push(*alphanumeric_permutations(input, length, current_str + input[i]))
  end
  return ret
end

begin
  combos = alphanumeric_permutations(POSSIBLE_CHARACTERS, 5, '')
  success_f = File.open("success", "a")
  fail_f = File.open("failure", "a")
  i = 0
  until combos[i].nil?
    threads = []
    50.times do
      break if combos[i].nil?
      threads << Thread.new(i) do |thread_i|
        operation(combos[thread_i], thread_i, success_f, fail_f)
      end
      i += 1
    end
    sleep(0.1) until threads.all? { |t| !t.alive? }
    threads.each(&:kill)
  end

rescue IOError => e
  puts e
ensure
  success_f.close unless success_f.nil?
  fail_f.close unless fail_f.nil?
end
