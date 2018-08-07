require 'faraday'
require 'faraday_middleware'
require 'oauth2'
require 'httpauth'
require 'sinatra'
require 'dotenv'
require 'business_time'

Dotenv.load('.env')

PORT = 4567

firsttime = ENV['APP_ID'] == nil && ENV['SECRET'] == nil
if firsttime
  puts '次に開くfreeeの画面で@c-fo.comアカウントででfreeeにログインしておいてください。(Enterで進む)'
  STDIN.gets
  system 'open https://secure.freee.co.jp/'
  STDIN.gets
  puts "次に開くアプリ登録画面で 名前：'勤怠登録くん', callback url: 'http://127.0.0.1:#{PORT}/oauth/callback' を登録してください"
  STDIN.gets
  system 'open https://secure.freee.co.jp/oauth/applications'

  file = File.open('.env','a')
  puts '登録後表示されたAPP_IDを入力してください'
  app_id = STDIN.gets
  file.puts "APP_ID=#{app_id}"
  puts '登録後表示されたSECRETを入力してください'
  secret = STDIN.gets
  file.puts "SECRET=#{secret}"
  file.close

  file = File.open("#{Dir.home}/.bash_profile",'a')
  file.puts "alias kintai='cd #{Dir.pwd};bundle exec ruby #{Dir.pwd}/kintai.rb'"
  file.close
  puts '設定が完了しました。勤怠登録を開始します。今後ターミナルでkintaiコマンドが使えるようになります'
  STDIN.gets
end

Dotenv.load('.env')

raise '環境変数の設定に失敗しました' if ENV['APP_ID'] == nil || ENV['SECRET'] == nil

HOST = 'https://api.freee.co.jp'

set :port, PORT

get '/authorization' do
  redirect "https://secure.freee.co.jp/oauth/authorize?client_id=#{ENV['APP_ID']}&redirect_uri=http%3A%2F%2F127.0.0.1%3A4567%2Foauth%2Fcallback&response_type=code"
end

get '/oauth/callback' do
  authorization_code = params['code']
  options = {
    site: 'https://api.freee.co.jp/',
    authorize_url: '/oauth/authorize',
    token_url: '/oauth/token',
    ssl: { verify: false },
    use_not_over_mode: ARGV.include?('NOT_OVER')
  }
  if options[:use_not_over_mode]
    puts '22時以降は忖度します'
  end

  client = OAuth2::Client.new(ENV['APP_ID'], ENV['SECRET'], options) do |conn|
    conn.request :url_encoded
    conn.request :json
    conn.response :json, content_type: /\bjson$/
    conn.adapter Faraday.default_adapter
  end

  params = {
    grant_type: 'authorization_code',
    code: authorization_code,
    redirect_uri: "http://127.0.0.1:#{PORT}/oauth/callback",
    headers: {
      'Content-Type' => 'application/json',
      'Authorization' => HTTPAuth::Basic.pack_authorization(ENV['APP_ID'], ENV['SECRET'])
    }
  }

  token = client.get_token(params).token

  access_token = OAuth2::AccessToken.new(client, token)
  access_token.get('/api/1/users/me?companies=true').response.env[:body];nil

  me = access_token.get("#{HOST}/hr/api/v1/users/me").response.env[:body];nil
  emp_id = me['companies'].find{|c| c['name'] == 'フリー株式会社'}['employee_id']

  ((Date.today - 15)..(Date.today - 1)).each do |date|
    target_date = date.to_s
    lines = `pmset -g log | grep "Kernel Idle sleep preventers" | grep #{target_date}`
    if !date.workday?
      puts "#{target_date} は休日なのでスキップします"
      next
    end
    if lines == ''
      puts "#{target_date} の元データが無いようです。。。"
      next
    end
    times = lines.split("\n").map {|line| line.match(/\d{4}-\d{2}-\d{2}\s(\d{2}:\d{2}:\d{2})/)[1]}
    start_time = times.first
    end_time = times.last

    if end_time[0..1].to_i >= 22
      end_time = '22:00:00'
    end
    if access_token.get( "#{HOST}/hr/api/v1/employees/#{emp_id}/work_records/#{target_date}").response.env[:body]['clock_in_at'] != nil
      puts "#{target_date} はすでに勤怠が登録されています"
      next
    end

    begin
      access_token.put(
        "#{HOST}/hr/api/v1/employees/#{emp_id}/work_records/#{target_date}",
        {
          :body =>{
            break_records: [ {clock_in_at: "#{target_date}T13:00:00.000+09:00",clock_out_at: "#{target_date}T14:00:00.000+09:00"}],
            clock_in_at: "#{target_date}T#{start_time}.000+09:00",
            clock_out_at: "#{target_date}T#{end_time}.000+09:00"
          }.to_json,
          :headers => {'Content-Type' => 'application/json'}
        }).response.env[:body]
      puts "#{target_date} の勤怠を#{start_time}~#{end_time}でつけました"
    rescue => e
      puts e.message
    end
  end
  Thread.new { sleep 1; Process.kill 'INT', Process.pid }
  puts '勤怠つけ終わりました'
  redirect "https://p.secure.freee.co.jp/#work_records/#{(Date.today + 1.month).strftime("%Y/%m")}/employees/#{emp_id}"
end

system "open http://127.0.0.1:#{PORT}/authorization"
