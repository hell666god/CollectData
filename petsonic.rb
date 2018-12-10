require 'curb'
require 'nokogiri'
require 'logger'
require 'csv'

@args = ARGV
if(!@args.include?("--url") || !@args.include?("--filename") || @args.length != 4)
  puts("CMD: ruby petsonic.rb --url https://www.petsonic.com/snacks-huesos-para-perros/ --filename out.csv")
  exit(0)
end

###
# Variables
@postfixUrl = "?content_only=1&p="

@regexForLink = /(https?:\/\/?[\da-z\.-]+\.[a-z\.]{2,6}[\/\w \.-]*\/?)/
@regexForWidth = />(.*)</
@regexForPrice = />(\d*.\d*).*</
@regexForName = /\n\s*(.*)\n/

@xpathForLink = "//ul[contains(@id, 'product_list')]//li//a[contains(@class, 'lnk_view')]"
@xpathFieldSet = "//fieldset//ul[contains(@class, 'attribute')]/li"
@xpathWidth = "//span[contains(@class, 'radio_label')]"
@xpathPrice = "//span[contains(@class, 'price')]"
@xpathForImg = "//div[contains(@id, 'image')]//img"
@xpathForName = "//h1[contains(@itemprop, 'name')]"

###
# Get CurlAgent with settings
def getCurl
  curl = Curl::Easy.new
  curl.useragent = @userAgent
  return curl
end

###
# Execute URL and return Curl object
# @param curl Curl object
# @param url string
# @return
def execUrl(curl, url)
  curl.url = url
  curl.perform
  return curl
end

###
# Parse html string by xpath
# @param html string
# @param xpath string
# @return array
def parseHtml(html, xpath)
  doc = Nokogiri::HTML(html)
  return doc.xpath(xpath).to_a
end

###
# Parse strings array by Regex
# @param array Strings array
# @param regex
# @return array
def parseRegex(array, regex)
  result = []
  array.each { |a| result.push(a.to_s.match(regex).to_a) }
  return result
end

###
# Parse and return fields hash
# @param html String
# @return Hash
def getFields(html)
  fields = parseHtml(html, @xpathFieldSet).to_a

  cost = Hash.new

  fields.each do |field|
    width = parseRegex(parseHtml(field.to_s, @xpathWidth), @regexForWidth)[0][1]
    price = parseRegex(parseHtml(field.to_s, @xpathPrice), @regexForPrice)[0][1]

    cost[width] = price
  end
  cost
end

@inputURL = @args[ @args.index("--url") + 1 ]
@inputFilename = @args[ @args.index("--filename") + 1 ]

@curl = getCurl
@csv = CSV.open(@inputFilename, "wb")
@logger = Logger.new(STDOUT)
@logger.level = Logger::INFO


@logger.info("URL: #{@inputURL}")
@logger.info("Filename: #{@inputFilename}")


@logger.info('Start script')
@links = []
@threads = []

###
# Parse pages and write in csv file
# @param links array
# @param csv Csv
def parseAndWriteToCsv(links, csv)
  curl = getCurl

  links.each do |link|
    html = execUrl(curl, link[0]).body_str

    imgLink = parseRegex( parseHtml( html, @xpathForImg ), @regexForLink )[0][1]
    name = parseRegex( parseHtml( html, @xpathForName ), @regexForName )[0][1]

    fields = getFields(html)
    fields.each do |width, price|
      @logger.info("Write to #{@inputFilename}: #{data = ["#{name} #{width}", price, imgLink]}")
      csv << data
    end
  end
end

indexPage = 1
curl_url = @inputURL

###
# Main loop
while execUrl(@curl, curl_url).status.to_i == 200

  @logger.info("#{curl_url} : #{@curl.status}")

  @links = parseRegex(parseHtml(@curl.body_str, @xpathForLink), @regexForLink)

  th = Thread.new do
    parseAndWriteToCsv(@links, @csv)
  end

  @threads.push(th)

  indexPage +=1
  curl_url = "#{@inputURL}#{@postfixUrl}#{indexPage}"
end

@threads.each {|thread| thread.join}

@logger.info("Data was write in #{@inputFilename} file")



