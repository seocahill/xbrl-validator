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
    response = BusinessRulesValidator.new(params).validate_document
    [200, response.to_json]
  rescue => e
    error = { message: e.message }
    [500, error.to_json]
  end
end

class BusinessRulesValidator

  MANDATORY_TAGS = [
    'uk-bus:EntityCurrentLegalOrRegisteredName',
    'uk-bus:StartDateForPeriodCoveredByReport',
    'uk-bus:EndDateForPeriodCoveredByReport',
    'uk-gaap:ProfitLossOnOrdinaryActivitiesBeforeTax'
  ]

  def initialize(params)
    @messages = {}
    file = File.open(File.join('/ixbrl', params["filename"]))
    @doc = Nokogiri::XML(file)
  end

  def validate_document
    @messages[:schema_ref_test] = schema_ref_test
    @messages[:mandatory_tags_present] = mandatory_tags_present
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

  def mandatory_tags_present
    missing_tags = check_for_missing_tags
    if missing_tags.any?
      "invalid: the following tags are missing or empty #{missing_tags.join('; ')}"
    else
      "valid"
    end
  end

  def check_for_missing_tags
    MANDATORY_TAGS.map do |tag|
      tag_content = @doc.xpath("//*[@name='#{tag}']")&.first&.text
      tag if tag_content.to_s.strip.empty?
    end.compact
  end
  
  def test_period_dates
    skip 
    # Report period start date cannot be later than the selected Revenue accounting period start date (<value>).
    # Period End Date (uk- bus:EndDateForPeriodCoveredByRepo rt) is <end_date> but must be 2011-12- 31 or later
    # Report period end date cannot be before the selected Revenue accounting period end date (<value>).
    # Report period end date must fall within the selected Revenue accounting period.
  end

  def test_duplicate_facts
    skip # Inconsistent duplicate facts, <fact name>, for context <context>.
  end

  def context_id_scheme
    skip # Context entity identifier scheme (<value>) is not supported n/a
  end

  def context_schemes_consistent
    skip # Contexts do not all use the same identifier and the same scheme.
  end

  def cro_number
    skip # Companies Registration Office Number (ie- common:CompaniesRegistrationOffice Number) is missing If there is at least one context entity where the identifier scheme is 'http://www.cro.ie/'
  end

  def context_entity_id
    skip # Context entity identifier (<value>) is not consistent with Revenue records (<value)>)
  end
end


