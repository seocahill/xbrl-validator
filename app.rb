require 'sinatra'
require 'nokogiri'
require 'json'

set :server, :puma
set :bind, '0.0.0.0'

get '/' do
  200
end

get '/validate/:filename' do
  content_type :json
  begin
    response = XbrlValidator.new(params).validate_document
    [200, response.to_json]
  rescue => e
    error = { message: e.message }
    [500, error.to_json]
  end
end

class XbrlValidator

  def initialize(params)
    @messages = {}
    file = File.open(File.join('/ixbrl', params["filename"]))
    @doc = Nokogiri::XML(file)
  end

  def validate_document
    @messages[:schema_ref_test] = schema_ref_test
    @messages[:company_name_present] = company_name_present
    @messages
  end

  def schema_ref_test
    schemas = ["http://www.xbrl-ie.net/public/ci/2012-12-01/gaap/core/2012-12-01/ie-gaap-full-2012-12-01.xsd"]
    schemaRef = @doc.xpath('//link:schemaRef').first.attributes["href"].value
    if schemas.include? schemaRef
     "valid"
    else
     "invalid: #{schemaRef} is not a valid schema"
    end
  end

  def company_name_present
    company_name = doc.xpath("//ix:nonNumeric[@name='uk-bus:EntityCurrentLegalOrRegisteredName']")&.first&.text
    if company_name&.empty?
      "invalid: uk-bus:EntityCurrentLegalOrRegisteredName must be present"
    else
      "valid"
    end
  end
end


