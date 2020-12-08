require 'capybara'
require 'capybara-screenshot'
require 'capybara/cuprite'
require 'open-uri'
require 'pry'
require 'pry-rails'
require 'pry-byebug'
require 'two_captcha'

@doctor_id = ENV['DOCTORID']
@id_number = ENV['IDNUMBER']
@b_year    = ENV['BYEAR']
@b_month   = ENV['BMONTH']
@b_day     = ENV['BDAY']
@auto      = ENV['AUTO']
@headless  = ENV['HEADLESS']
@client = TwoCaptcha.new(ENV['TWOCAPTCHA']) if @auto == 'yes'

def initialize_cuprite
  Capybara.javascript_driver = :cuprite
  Capybara.register_driver :cuprite do |app|
    Capybara::Cuprite::Driver.new(app, window_size: [1680, 1040], headless: @headless, browser_options: { 'no-sandbox': nil })
  end
  @session = Capybara::Session.new(:cuprite)
  @session.driver.add_headers({ 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Safari/604.1.38' })
  @session.driver.add_headers({ 'Accept-Language': 'zh-tw' })
end

def input_fill_in
  @session.find('#radInputNum_1').click
  @session.find('#txtIdno').fill_in(with: @id_number)
  @session.find('#ddlBirthYear').select(@b_year)
  @session.find('#ddlBirthMonth').select(@b_month)
  @session.find('#ddlBirthDay').select(@b_day)
end

def auto_solve_captcha
  puts '處理驗證碼中...'
  captcha = @client.decode!(url: @session.find('#imgVlid')['src'])
  captcha.text
end

def manual_solve_captcha
  File.write("./tmp/#{@id_number}_#{@doctor_id}.png", URI.parse(@session.find('#imgVlid')['src']).open.read)
  `open "./tmp/#{@id_number}_#{@doctor_id}.png"`
  puts '請輸入驗證碼六碼並按 enter'
  $stdin.gets
end

def deal_with_captcha
  ans = if @auto == 'yes'
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
  # @session.save_and_open_screenshot
  puts '預約失敗'
  go_to_doctor_page
end

def go_to_doctor_page
  url = "https://reg.ntuh.gov.tw/webadministration/ClinicListUnderSpecificTemplateIDSE.aspx?ServiceIDSE=#{@doctor_id}"
  @session.visit url
end

def register_table
  @session.find('#DoctorServiceListInSeveralDaysTemplateIDSE_GridViewDoctorServiceList')
end

def basic_info
  [@id_number, @b_year, @b_month, @b_day].each do |info|
    abort('Fail: 基本資料未填') if info.nil?
  end

  puts "身份證字號: #{@id_number}"
  puts "出生年月日: #{@b_year} #{@b_month} #{@b_day}"
end

initialize_cuprite
go_to_doctor_page
basic_info
table_links = register_table.all('a', text: '掛號')
if table_links.size.positive?
  table_links.each do |link|
    link.click
    sleep(0.2)
    input_fill_in
    sleep(0.2)
    deal_with_captcha
    @session.find('input#btnOK').click
    if @session.has_selector?('#showResult')
      show_result
      break
    elsif @session.has_selector?('#palPatBaseP1')
      show_first_result
      break
    else
      deal_with_error
    end
  end
else
  puts register_table.all('tr').last.all('td')[0].text
end
