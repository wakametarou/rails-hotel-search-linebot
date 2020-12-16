class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      # p '不正なリクエストです。'
      return head :bad_request
    end
    # p '正しいリクエストです。'
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          # search_and_create_message(event.message['text'])
          message = search_and_create_message(event.message['text'])
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private
 
  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def search_and_create_message(keyword)
    http_client = HTTPClient.new
    url = 'https://app.rakuten.co.jp/services/api/Travel/KeywordHotelSearch/20170426'
      query = {
        'keyword' => keyword,
        'applicationId' => ENV['RAKUTEN_APPID'],
        'hits' => 5,
        'responseType' => 'small',
        'datumType' => 1,
        'formatVersion' => 2
      }
    response = http_client.get(url, query)
    response = JSON.parse(response.body)
    # p response['pagingInfo']

    if response.key?('error')
      text = "この検索条件に該当する宿泊施設が見つかりませんでした。\n条件を変えて再検索してくだい。"
      {
        type: 'text',
        text: text
      }
    else
      {
        type: 'flex',
        altText: '宿泊検索の結果です。',
        contents: set_carousel(response['hotels'])
      }
    end
  end
  def set_carousel(hotels)
    bubbles = []
    hotels.each do |hotel|
      bubbles.push set_bubble(hotel[0]['hotelBasicInfo'])
    end
    {
      type: 'carousel',
      contents: bubbles
    }
  end
end
