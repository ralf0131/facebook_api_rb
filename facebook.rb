require 'mechanize'
require 'json'
require 'yaml'

class FacebookAPISample

  # API doc: https://developers.facebook.com/docs/reference/ads-api/
  # Using http://developers.facebook.com/tools/explorer/ to debug your api calls.

  # used for login
  @@user_name = ''
  @@password  = ''
  # used to call api, these are defined when you create your app
  @@client_id = ''
  @@client_secret = ''
  @@base_url = ''

  @@access_token = ''

  def getAccessToken(agent, scope)
    # change this to redirect to your own url if you want.
    redirect_uri = 'http://www.facebook.com/connect/login_success.html'
    login_url = 'https://www.facebook.com/dialog/oauth?' +
      buildUrlParams({
        'client_id' => @@client_id,
        'redirect_uri' => redirect_uri,
        'scope' => scope
      })
    login_page = agent.get(login_url)
    # you should make your program behave like a human
    sleep(2.5)
    # login
    login_form = login_page.forms[0]
    login_form.field_with(:name => 'email').value = @@user_name
    login_form.field_with(:name => 'pass').value = @@password
    puts "Logging in..."
    confirm_page = login_form.submit
    puts "Logging completed."
    sleep(2)

    # finding out the confirm form
    puts "Getting AUTH code..."
    confirm_form = confirm_page.forms.select{|form| form.action =~ /oauth/}[0]
    if confirm_form != nil then
      # you need confirm for the first time to get a new permission
      puts "Clicking the confirm button..."
      confirm_button = confirm_form.button_with(:name => "__CONFIRM__")
      code_page = agent.submit(confirm_form, confirm_button)
      # get AUTH code for generating access token
      code = /[a-zA-z0-9\-_]+#_=_/.match(code_page.body).to_s
    else
      # if you have requested before, confirm is not needed.
      # get AUTH code for generating access token
      code_url = confirm_page.uri.to_s
      # "https://www.facebook.com/connect/login_success.html?code=YOUR_CODE"
      code = URI.parse(code_url).query.split('=')[1]
    end
    raise 'invalid auth code.'+code unless /^[a-zA-Z0-9_-]*/ =~ code

    # get access token
    puts "Getting access token..."
    token_url_params = buildUrlParams({
      'client_id' => @@client_id,
      'redirect_uri' => redirect_uri,
      'client_secret' => @@client_secret,
      'code' => code
    })
    token_url = @@base_url + "/oauth/access_token?" + token_url_params
    access_token_page = agent.get(token_url)
    sleep(2.5)
    # parse token
    access_token_params = CGI::parse(access_token_page.body)
    access_token = access_token_params['access_token'][0]
    # should return 0 if matched
    raise 'invalid access token.' unless /^[a-zA-Z0-9]*$/ =~ access_token
    puts "Successfully got access token."
    access_token
  end

  def buildUrlParams(param_hash)
    # convert hash to string like "param1=value1&param2=value2"
    param_hash.collect{|k, v| "#{k}=#{v}"}.join('&')
  end

  def saveAccessToken()
    token_file = File.open("token", 'w+')
    token_file << @@access_token
    token_file.close
  end

  def postToMyWall(agent, msg)
    url = @@base_url + '/me/feed'
    agent.post(url, {
      'access_token' => @@access_token,
      'message'      => msg
    })
  end

  def whoAmI(agent)
    url = @@base_url + '/me?' + buildUrlParams({'access_token' => @@access_token})
    me_json = JSON.parse(agent.get(url).body)
    puts "Welcome #{me_json['name']}!"
  end

  def parseCredentials(conf_file_str)
    begin
      conf = YAML.load_file(conf_file_str)
    rescue Exception => e
      raise 'Error parsing config file.'
    end
    creds = conf['credentials'][0]
    # used for login
    @@user_name = creds['username']
    @@password  = creds['password']
    # used to call api, these are defined when you create your app
    @@client_id = creds['client_id']
    @@client_secret = creds['client_secret']
    @@base_url = creds['base_url']
  end

  def FacebookAPISample.main
    agent = Mechanize.new
    fb = FacebookAPISample.new
    fb.parseCredentials('./config.yml')
    @@access_token = File.read('./token')
    if !@@access_token.empty? && /^[a-zA-Z0-9]*$/ =~ @@access_token then
      # token already exist
    else
      @@access_token = fb.getAccessToken(agent, 'user_events')
      fb.saveAccessToken()
    end

    # now start do what you want to do!
    # fb.postToMyWall(agent, 'Hello World from ruby!')
    fb.whoAmI(agent)
  end

end

puts FacebookAPISample.main
