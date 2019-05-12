desc "This task is called by the Heroku scheduler add-on"
task :update_feed => :enviroment do
  require 'line/bot'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

client ||= Line::Bot::Client.new{ |config|
  config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
  config.channel_token = ENV["LINE_CHANNNEL_TOKEN"]
}

#　使用するxmlデータ
url = "https://www.drk7.jp/weather/xml/13.xml"

# xmlデータをパース
xml = open( url ).read.toutf8
doc = REXML::Document.new(xml)
# パスの共通部分を変数化(area[4]="東京地方")
xpath = 'weatherforecast/pref/area[4]/info/railnfallchance/'

per06to12 = doc.elements[xpath + 'period[2]'].text
per12to18 = doc.elements[xpath + 'period[3]'].text
per18to24 = doc.elements[xpath + 'period[4]'].text

# メッセージを送信する降水確率の下限を設定
min_per = 20
if per06to12.to_i >= min_per || per12to18.to_i >= min_per || per18to24.to_i >= min_per
  word1 =
  ["GM！！！",
  "Hello, world!",
  "Good Morning!",
  "おはよう！",
  "いい朝だね"].sample
  word2 =
  ["今日も一日がんばろう",
    "May the Force be with you",
    "いい一日を！",
    "油断せずにいこう",
    "最高だ"].sample

mid_per = 50
if per06to12.to_i >= mid_per || per12to18.to_i >= mid_per || per18to24 >= mid_per
  word3 = "今日は雨が振りそうだよ！傘を忘れないでね"
else
  word3 = "今日は雨が降るかもしれないから折りたたみ傘を持つと安心かも"
end

push =
  "#{word1}\n#{word3}\n降水確率は以下の通りです。\n  6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\n#{word2}"

# メッセージの発信先idを配列で渡す必要があるため、userテーブルよりpluck関数を使ってidを配列で取得
user_ids = User.all.pluck(:line_id)
message = {
  type: 'text'
  text: push
}
response = client.multicast(user_ids, message)
end
"OK"
end

end