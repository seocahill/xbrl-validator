require 'sinatra'
require 'nokogiri'
require 'json'
require 'time'
require_relative 'lib/converter'

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

  VALID_SCHEMAS = [
    "http://www.xbrl-ie.net/public/ci/2012-12-01/gaap/core/2012-12-01/ie-gaap-full-2012-12-01.xsd",
    "http://www.xbrl-ie.net/public/ci/2012-12-01/ifrs/core/2012-12-01/ie-ifrs-full-2012-12-01.xsd",
    "http://www.xbrl-ie.net/public/ci/2016-08-01/FRS-101/2016-08-01/FRS-101-ie-2016-08-01.xsd",
    "http://www.xbrl-ie.net/public/ci/2016-08-01/FRS-102/2016-08-01/FRS-102-ie-2016-08-01.xsd",
    "http://www.xbrl-ie.net/public/ci/2016-08-01/IFRS/2016-08-01/IFRS-ie-2016-08-01.xsd"
  ]

  MANDATORY_TAGS = [
    'uk-bus:EntityCurrentLegalOrRegisteredName',
    'uk-bus:StartDateForPeriodCoveredByReport',
    'uk-bus:EndDateForPeriodCoveredByReport',
    'uk-gaap:ProfitLossOnOrdinaryActivitiesBeforeTax'
  ]

  VALID_CONTEXT_ENTITY_IDENTIFIERS = [
    "http://www.revenue.ie/",
    "http://www.cro.ie/",
  ]

  def initialize(params)
    @messages = {}
    file = File.open(File.join('/ixbrl', params["filename"]))
    @doc = Nokogiri::XML(file)
    @log = Logger.new(File.new(File.join(__dir__, "dev.log"), 'w'))
  end

  def validate_document
    @messages[:validate_schema] = validate_schema
    @messages[:schema_ref] = schema_ref
    @messages[:mandatory_tags_present] = mandatory_tags_present
    @messages[:period_dates] = period_dates
    @messages[:duplicate_facts] = duplicate_facts
    @messages[:context_scheme_consistent] = context_scheme_consistent
    @messages[:context_scheme_allowed] = context_scheme_allowed
    @messages[:context_identifiers] = context_identifiers
    @messages[:cro_number_required] = cro_number_required
    @messages
  end

  def validate_schema
    errors = []
    validate_ixbrl(errors)
    validate_xbrl(errors)
    message = errors.any? ? "invalid" : "valid"
    {message: message, errors: errors}
  end

  def validate_ixbrl(errors)
    begin
      file = "./xsd/xhtml-inlinexbrl-1_0.xsd"
      xsd = Nokogiri::XML::Schema(File.open(file))
      xsd.validate(@doc).each do |error|
        errors << error
      end
    rescue Nokogiri::XML::SyntaxError => e
      errors << "caught exception: #{e}"
    end
  end

  def validate_xbrl(errors)
    xbrl_doc = Converter.new(@doc).to_xbrl
    begin
      file = "./xsd/ie/ie-gaap-full-2012-12-01.xsd"
      xsd = Nokogiri::XML::Schema(File.open(file))
      xsd.validate(xbrl_doc).each do |error|
        errors << error
      end
    rescue Nokogiri::XML::SyntaxError => e
      errors << "caught exception: #{e}"
    end
  end

  def schema_ref
    schemaRef = @doc.xpath('//link:schemaRef').first.attributes["href"].value
    if VALID_SCHEMAS.include? schemaRef
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

  # The following checks require data on ROS services and therefore are n/a:
  # - Report period start date cannot be later than the selected Revenue accounting period start date (<value>).
  # - Report period end date cannot be before the selected Revenue accounting period end date (<value>).
  # - Report period end date must fall within the selected Revenue accounting period.

  def period_dates
    end_date = @doc.xpath("//*[@name='uk-bus:EndDateForPeriodCoveredByReport']")&.first&.text&.strip
    if end_date && (Time.parse(end_date) > Time.parse(" 2011-12-31"))
      "valid"
    else
      "invalid: Period End Date is #{end_date} but must be 2011-12-31 or later"
    end
  end

  def duplicate_facts
    # exclude facts where tupleRef attr is present as they can have duplicate values
    facts = @doc.xpath("//ix:nonFraction[not(@tupleRef)] | //ix:nonNumeric[not(@tupleRef)]")
    dictionary = {}
    duplicate_facts = []

    facts.each do |fact|
      value = fact_value(fact) # need to transform currency values before comparing
      name = fact.attributes["name"].value
      context = fact.attributes["contextRef"].value
      dictionary[name] ||= {}

      if dictionary[name][context].nil?
        dictionary[name][context] = { value: value, line_number: fact.line }
      elsif dictionary[name][context][:value] != value
        duplicate_fact = add_duplicate_fact(fact, value, dictionary[name][context])
        duplicate_facts << duplicate_fact
      end
    end

    @log.debug("dictionary is #{dictionary.inspect}")

    message = duplicate_facts.any? ? "invalid" : "valid"
    { message: message, duplicate_facts: duplicate_facts }
  end

  def context_scheme_consistent
    context_schemes = @doc.xpath("//*[@scheme]").map { |c| c.attributes["scheme"].value }.uniq
    if context_schemes.length > 1
      "invalid: Contexts do not all use the same identifier and the same scheme"
    else
      "valid"
    end
  end

  def context_scheme_allowed
    context_scheme = @doc.xpath("//*[@scheme]").first.attributes["scheme"].value
    if VALID_CONTEXT_ENTITY_IDENTIFIERS.include? context_scheme
      "valid"
    else
      "invalid: #{context_scheme} is not a valid scheme"
    end
  end

  def context_identifiers
    tax_numbers = @doc.xpath("//*[@scheme='http://www.revenue.ie/']").map { |c| c.text }.uniq
    cro_numbers = @doc.xpath("//*[@scheme='http://www.cro.ie/']").map { |c| c.text }.uniq

    if tax_numbers.all? { |id| id =~ /^\d{7}\D{1,2}$/ }
      # a seven digit number with one or two check characters
      "valid"
    elsif cro_numbers.all? { |id| id =~ /^\d{5,6}$/ }
      #  up to six digits with no alpha characters
      "valid"
    else
     "invalid: One or more context_identifer numbers malformed or missing"
    end
  end

  def cro_number_required
    context_schemes = @doc.xpath("//*[@scheme]").map { |c| c.attributes["scheme"].value }.uniq
    return "valid" unless context_schemes.include? "http://www.cro.ie/" 
    tag_content = @doc.xpath("//ix:nonNumeric[@name='ie-common:CompaniesRegistrationOfficeNumber']")&.first&.text
    if tag_content.to_s.strip.empty?
      "invalid: Must tag CRO number if using http://www.cro.ie/ identifier scheme"
    else
      "valid"
    end
  end

  private

  def add_duplicate_fact(fact, value, entry)
    { 
      name: fact.attributes["name"].value, 
      context: fact.attributes["contextRef"].value,
      value: value,
      line_number: fact.line,
      conflicting_fact: entry
    }
  end

  def check_for_missing_tags
    MANDATORY_TAGS.map do |tag|
      tag_content = @doc.xpath("//*[@name='#{tag}']")&.first&.text
      tag if tag_content.to_s.strip.empty?
    end.compact
  end

  def fact_value(fact)
    if fact.name == "nonFraction"
      currency_value = fact.text.gsub(/\D/, '').to_i
      fact.attributes["sign"]&.value == '-1' ? (currency_value * -1) : currency_value
    else
      fact.text
    end
  end
end


