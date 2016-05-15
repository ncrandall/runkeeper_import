require 'bundler/setup'
Bundler.require(:default)
require 'zip'


class Importer

  attr_accessor :gpx_hashes, :curl

  def initialize(args = {})
    @username = args[:username]
    @password = args[:password]
    @gpx_zip_file = args[:gpx_zip_file]
    @gpx_hashes = []
    @curl = curl_setup
  end

  def import
    load_gpx_files
    create_session
    upload_files
  end

  def bulk_delete(ids)
    create_session
    ids.each do |id|
      @curl.url = "https://runkeeper.com/delete/activity?activityId=#{id}"
      @curl.http_get
    end
  end

  private

  def load_gpx_files
    Zip::File.open(@gpx_zip_file) do |zip_file|
      zip_file.each do |entry|
        next unless entry.name.end_with?('.gpx')
        begin
          @gpx_hashes << {name: entry.name, gpx_file: GPX::GPXFile.new(:gpx_data => entry.get_input_stream.read) }
        rescue Exception => e
          puts "Couldn't load gpx_file: #{entry.name}"
        end
      end
    end
  end

  def upload_files
    @gpx_hashes.each do |gpx_hash|
      begin
        create_new_activity(gpx_hash[:gpx_file])
        gpx_hash[:activity_id] = @curl.redirect_url.match(/activity\/(\d+)/)[1]
      rescue Exception => e
        puts "Unable to create activity #{gpx_hash[:name]} - #{e.message}"
      end
    end
  end

  def create_session
    initial_session
    @curl.post_body = "_eventName=submit&redirectUrl=&flow=&failUrl=&email=#{URI.encode(@username)}&password=#{URI.encode(@password.encode)}" #&_sourcePage=DwCTKeR8O6VSMkQ2IKb_mRoc-IQ0sMyrmpVzZ9KGq7kaHPiENLDMq5qVc2fShqu5knVNNT0OC_8=&__fp=zVEC7V5q9lc='
    @curl.http_post
  end

  def initial_session
    @curl.url = "https://runkeeper.com/login"
    @curl.perform
  end

  def home
    @curl = "https://runkeeper.com/home"
    @curl.perform
  end

  def initial_new_activity
    @curl.url = "https://runkeeper.com/new/activity"
    c.perform
  end

  def create_new_activity(gpx_file)
    track_file_hash = track_file_hash(gpx_file)
    @curl.url = "https://runkeeper.com/new/activity"
    @curl.http_post(*gpx_post_fields(track_file_hash, gpx_file.distance(units: "miles")))
  end

  def gpx_post_fields(track_file_hash, distance)
    duration_hash = duration_hash(track_file_hash)
    start_time = get_start_time(track_file_hash)
    point_string = get_points_string(track_file_hash)
    [
        Curl::PostField.content('_eventName', 'save'),
        Curl::PostField.content('importFormat', 'gpx'),
        Curl::PostField.content('hasMap', 'true'),
        Curl::PostField.content('durationMs', '0'),
        Curl::PostField.content('points', point_string),
        Curl::PostField.content('activityType', 'RUN'),
        Curl::PostField.content('gymEquipment', 'NONE'),
        Curl::PostField.content('startTimeString', start_time.strftime("%Y/%-m/%-d %H:%M:%S.%L")),
        Curl::PostField.content('durationHours', duration_hash[:hours]),
        Curl::PostField.content('durationMinutes', duration_hash[:minutes]),
        Curl::PostField.content('durationSeconds', duration_hash[:seconds]),
        Curl::PostField.content('startHour', start_time.strftime("%I")),
        Curl::PostField.content('startMinute', start_time.strftime("%M")),
        Curl::PostField.content('am', start_time.hour < 12),
        Curl::PostField.content('distance', distance),
        Curl::PostField.content('activityViewableBy', 'PRIVATE')
    ]
  end

  def get_points_string(track_file_hash)
    str = ""
    points = track_file_hash["trackImportData"]["trackPoints"]
    points.each do |point|
      str << "#{point['type']},#{point['latitude']},#{point['longitude']},#{point['deltaTime']},0,#{point['deltaDistance']};"
    end
    str
  end

  def get_start_time(track_file_hash)
    Time.at(track_file_hash["trackImportData"]["startTime"] / 1000)
  end

  def duration_hash(track_file_hash)
    duration = Time.at(track_file_hash['trackImportData']['duration']/1000).utc
    { hours: duration.strftime("%H"), minutes: duration.strftime("%M"), seconds: duration.strftime("%S") }
  end

  def track_file_hash(gpx_file)
    trackFileUpload(gpx_file)
    JSON.parse(@curl.body_str)
  end

  def trackFileUpload(gpx_file)
    file = Tempfile.new("gpx_file")
    file << gpx_file.to_s

    @curl.url = 'https://runkeeper.com/trackFileUpload'
    @curl.multipart_form_post = true
    @curl.http_post(Curl::PostField.content('uploadType','.gpx'), Curl::PostField.file('trackFile', file.path))
    puts "Upload of track file returned #{curl.response_code} - #{curl.redirect_url}"
    @curl.multipart_form_post = false
  end

  def curl_setup
    c = Curl::Easy.new
    c.enable_cookies = true
    c.cookiejar = 'cookies.txt'
    c.cookiefile = 'cookies.txt'
    c
  end
end