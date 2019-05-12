class LinebotController < ApplicationController
  require 'line/bot'
  require 'open-uri'
  require 'kconv'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_form_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validates_signature(body, signature)
      erroer 400 do 'Bad Request' end
    end
    events = client.parse_events_form(body)
    events.each{ |event|
    case event
      # メッセージが送信された場合の対応（機能①）
    when Line::Bot::Event::MessageType::Text

      # event.message['text']：ユーザーから送られたメッセージ
      input = event.message['text']
      url = "https://www.drk7.jp/weather/xml/13.xml"
      xml = open( url ).read.toutf8
      doc = REXML::Document.new(xml)
      xpath = 'weatherforecast/pref/area[4]/'
      # 当日朝のメッセージの送信の下限値は20％としているが、明日・明後日雨が降るかどうかの下限値は30％としている
      min_per = 30
      case input
      # 「明日」or「あした」というワードが含まれる場合
      when /.*(明日|あした).*/
        # info[2]：明日の天気
        per06to12 = doc.elements[xpath + 'info[2]/rainfallchance/period[2]'].text
        per12t018 = doc.elements[xpath + 'info[2]/rainfallchance/period[3]'].text
        per18to24 = doc.elements[xpath + 'info[2]/rainfallchance/period[4]'].text
        if per06to12.to_i >= min_per || per12t018 >= min_per || per18to24.to_i >= min_per
          push = 
            "明日の天気だね。\n明日は雨が降るかも…！\n今のところの降水確率はこんな感じだよ。\n　　6〜12時 #{per06to12}%\n 12〜18時 #{per12to18}%\n 18〜24時 #{per18to24}%\n また明日の朝最新の天気予報で雨が降りそうだったら教えるね！"
        else
          push = 
            "明日の天気だね。\n明日は雨が降らない予定だよ！\nまた明日の朝の最新の天気予報で雨が降りそうだったら教えるね!"
        end

      when /.*(明後日|あさって).*/
        per06to12 = doc.elements[xpath + 'info[3]/rainfallchance/period[2]'].text
        per12t018 = doc.elements[xpath + 'info[3]/rainfallchance/period[3]'].text
        per18to24 = doc.elements[xpath + 'info[3]/rainfallchance/period[4]'].text
        if per06to12.to_i >= min_per || per12t018 >= min_per || per18to24.to_i >= min_per
          push =
            "明後日の朝だよね。\n見てみるね…\n明後日は雨が降るかも…！\n当日の朝に雨が降りそうだったらまた教えるね！"
        else
          push = 
          "明後日の朝？\n何か特別な予定でもあるのかな？\n明後日は雨は降らない予定だよ！\nまた当日の朝の天気予報で雨が降りそうだったら教えるね！"
        end
      when /.*(かわいい|可愛い|カワイイ|きれい|綺麗|キレイ|素敵|ステキ|すてき|面白い|おもしろい|ありがと|すごい|スゴイ|スゴい|好き|頑張|がんば|ガンバ).*/
        push =
          "ありがとう！！！\n優しい言葉をかけてくれるあなたはとても素敵です(^^)"
      when /.*(こんにちは|こんばんは|初めまして|はじめまして|おはよう).*/
        push =
          "こんにちは。\n声をかけてくれてありがとう\n今日があなたにとっていい日になりますように(^^)"
      else
        per06to12 = doc.elements[xpath + 'info/rainfallchance/period[2]'].text
        per12t018 = doc.elements[xpath + 'info/rainfallchance/period[3]'].text
        per18to24 = doc.elements[xpath + 'info/rainfallchance/period[4]'].text
        if per06to12.to_i >= min_per || per12t018 >= min_per || per18to24.to_i >= min_per
          word =
            ["雨だけど元気だしていこうね！",
            "雨に負けずファイト！",
            "雨なのにがんばっててえらい！"].sample
          push = 
            "今日の天気?\n今日は雨が降りそうだから傘があったほうが安心だよ。\n 6〜12時　#{per06to12}％\n　12〜18時　 #{per12to18}％\n　18〜24時　#{per18to24}％\n#{word}"
        else
          word =
            ["天気もいいから一駅歩いてみるのはどう？(^^)",
              "今日会う人のいいところを見つけて是非その人に教えてあげて(^^)",
              "素晴らしい一日になりますように(^^)",
              "雨が降っちゃったらごめんね(><)"].sample
          push = 
          "今日の天気？\n今日は雨は降らないみたいだよ。\n#{word}"
        end
      end
      #テキスト以外のメッセージが送信されたとき
    else
      push = "テキスト以外はわからないよ〜"
    end
    message = {
      type: 'text',
      text: push
    }
    client.reply_message(event['replyToken'], message)
    # 友達追加された場合
  when Line::Bot::Event::Follow
    #登録したユーザーのidをUserテーブルに保存
    line_id = event['source']['userId']
    User.create(line_id: line_id)
    #友達解除された場合
  when Line::Bot::Event::Unfollow
    line_id = event['source']['userId']
    User.find_by(line_id: line_id).destroy
  end
}
head :ok

end

private
def client
  @client ||= Line::Bot::Client.new{ |config|
  config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
  config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
}
  end
end
