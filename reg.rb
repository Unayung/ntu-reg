require 'capybara'
require 'capybara-screenshot'
require 'capybara/cuprite'
require 'open-uri'
require 'pry'
require 'pry-rails'
require 'pry-byebug'
require 'two_captcha'
require 'yaml'

if File.exist?('.env')
  config = YAML.safe_load(File.read('.env'))
  config.each do |k, v|
    ENV[k] = v.to_s
  end
end

@headless = ENV['HEADLESS'] == 'true'
@auto = ENV['AUTO'] == 'true'
@offset = 0

def initialize_services
  Capybara.javascript_driver = :cuprite
  Capybara.register_driver :cuprite do |app|
    Capybara::Cuprite::Driver.new(app, window_size: [1680, 1040], headless: @headless, browser_options: { 'no-sandbox': nil })
  end
  @session = Capybara::Session.new(:cuprite)
  @session.driver.add_headers({ 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Safari/604.1.38' })
  @session.driver.add_headers({ 'Accept-Language': 'zh-tw' })
  @client = TwoCaptcha.new(ENV['TWOCAPTCHA']) if @auto
end

def input_fill_in
  @session.find('#radInputNum_1').click
  @session.find('#txtIdno').fill_in(with: ENV['IDNUMBER'])
  @session.find('#ddlBirthYear').select(ENV['BYEAR'])
  @session.find('#ddlBirthMonth').select(ENV['BMONTH'])
  @session.find('#ddlBirthDay').select(ENV['BDAY'])
end

def auto_solve_captcha
  puts '處理驗證碼中...'
  captcha = @client.decode!(url: @session.find('#imgVlid')['src'])
  captcha.text
end

def manual_solve_captcha
  File.write("./tmp/#{ENV['IDNUMBER']}_#{ENV['DOCTORID']}.png", URI.parse(@session.find('#imgVlid')['src']).open.read)
  `open "./tmp/#{ENV['IDNUMBER']}_#{ENV['DOCTORID']}.png"`
  puts '請輸入驗證碼六碼並按 enter'
  $stdin.gets
end

def deal_with_captcha
  ans = if @auto
          auto_solve_captcha
        else
          manual_solve_captcha
        end
  @session.find('#txtVerifyCode').fill_in(with: ans)
rescue Exception => e
  abort("Fail: #{e}")
end

def show_result
  puts '掛號成功'
  puts "姓名: #{@session.find('#ShowResult').all('tr')[0].all('td')[1].text}"
  puts "時間: #{@session.find('#ShowResult').all('tr')[1].all('td')[1].text}"
  puts "科別: #{@session.find('#ShowResult').all('tr')[3].all('td')[1].text}"
  puts "診別: #{@session.find('#ShowResult').all('tr')[4].all('td')[1].text}"
  puts "醫師: #{@session.find('#ShowResult').all('tr')[5].all('td')[1].text}"
  puts "診號: #{@session.find('#ShowResult').all('tr')[6].all('td')[1].text}"
  puts "看診地點: #{@session.find('#ShowResult').all('tr')[9].all('td')[1].text}"
end

def show_first_result
  puts '初診身份掛號成功，請至查詢系統查詢診號'
  puts "時間: #{@session.find('#ShowTime').text}"
  puts "科別: #{@session.find('#ShowDept').text}"
  puts "診別: #{@session.find('#ShowClinic').text}"
  puts "醫師: #{@session.find('#ShowDt').text}"
end

def deal_with_error
  @offset += 1
  puts '掛號失敗，嘗試下一個可掛號時段'
  main(false, @offset)
end

def go_to_doctor_page
  url = "https://reg.ntuh.gov.tw/webadministration/ClinicListUnderSpecificTemplateIDSE.aspx?ServiceIDSE=#{ENV['DOCTORID']}"
  @session.visit url
end

def basic_info
  [ENV['IDNUMBER'], ENV['BYEAR'], ENV['BMONTH'], ENV['BDAY']].each do |info|
    abort('Fail: 基本資料未填') if info.nil?
  end

  puts "身份證字號: #{ENV['IDNUMBER']}"
  puts "出生年月日: #{ENV['BYEAR']} #{ENV['BMONTH']} #{ENV['BDAY']}"
end

def reg_info
  puts "-=-=-= 嘗試預約掛號 -=-=-="
  puts "時間: #{@session.find('#ShowTime').text}"
  puts "科別: #{@session.find('#ShowDept').text}"
  puts "診別: #{@session.find('#ShowClinic').text}"
  puts "醫事人員: #{@session.find('#ShowDt').text}"
end

def main(is_first_time, offset)
  initialize_services if is_first_time
  basic_info
  go_to_doctor_page
  table_links = @session.find('#DoctorServiceListInSeveralDaysTemplateIDSE_GridViewDoctorServiceList').all('a', text: '掛號')
  if table_links.size.positive? && offset < table_links.size
    link = table_links[offset]
    link.click
    reg_info
    sleep(0.3)
    input_fill_in
    deal_with_captcha
    @session.find('input#btnOK').click
    if @session.has_selector?('#showResult')
      show_result
    elsif @session.has_selector?('#palPatBaseP1')
      show_first_result
    else
      deal_with_error
    end
  elsif table_links.size.positive? && offset = table_links.size
    puts "已嘗試所有可掛號時段，無法完成預約掛號"
  else
    puts "無可掛號時段或#{@session.find('#DoctorServiceListInSeveralDaysTemplateIDSE_GridViewDoctorServiceList').all('tr').last.all('td')[0].text}"
  end
end

main(true, @offset)
