require 'sinatra'
require 'nokogiri'
require 'json'
require 'pry'

configure { set :server, :puma }

post '/validate' do
  content_type :json
  validation_results = XbrlInstanceValidator.new(params).validate_document
  [200, validation_results]
end

class XbrlInstanceValidator

  def initialize(params)
    @params = params
    @errors = []
  end

  def validate_document
    stages = [
      :xml_well_formed,
      :ixbrl_xhtml_schema_valid,
      :taxonomy_schema_ref_valid,
      :ixbrl_spec_rules,
      :dts_discovery,
      :xbrl_instance_schema_valid,
      :xbrl_spec_rules,
      :custom_rules
    ]
    current_stage = ""
    stages.each do |stage|
      current_stage = stage
      send(stage, @params, @errors)
      break if @errors.any?
    end
    {validation_stage: current_stage.to_s, errors: @errors}.to_json
  end

  private

  def xml_well_formed(params, errors)
    ixbrl_instance = params["ixbrl_instance"]
    begin
      Nokogiri::XML(ixbrl_instance) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
      errors << "caught exception: #{e}"
    end
    puts "=" * 99
    puts "well formed validation complete"
    puts "=" * 99
    errors
  end

  def ixbrl_xhtml_schema_valid(params, errors)
    ixbrl_instance = params["ixbrl_instance"]
    begin
      parsed_doc = Nokogiri::XML(ixbrl_instance)
      file = "xsd/xhtml-inlinexbrl-1_0.xsd"
      xsd = Nokogiri::XML::Schema(File.open(file))
      lines = ixbrl_instance.each_line
      xsd.validate(parsed_doc).each do |error|
        binding.pry
        extract = lines.take(error.line).last(5) rescue "no extract"
        errors << {line: error.line, message: error.message, extract: extract}
      end
    rescue Nokogiri::XML::SyntaxError => e
      errors << "caught exception: #{e}"
    end
    puts "=" * 99
    puts "xhtml schema valid"
    puts "=" * 99
    errors
  end

  def taxonomy_schema_ref_valid(params, errors)
    puts "=" * 99
    puts "schema ref valid"
    puts "=" * 99
    errors
  end

  def ixbrl_spec_rules(params, errors)
    puts "=" * 99
    puts "ixbrl spec rules validation complete"
    puts "=" * 99
    errors
  end

  def dts_discovery(params, errors)
    puts "=" * 99
    puts "dts dts_discovery complete"
    puts "=" * 99
    errors
  end

  def xbrl_instance_schema_valid(params, errors)
    # xbrl_instance = params["xbrl_instance"]
    # begin
    #   parsed_doc = Nokogiri::XML(xbrl_instance) { |config| config.strict }
    #   xsd_entry_file = "xsd/ie/ie-gaap-main-2012-12-01.xsd"
    #   xsd = Nokogiri::XML::Schema(File.open(xsd_entry_file))
    #   lines = xbrl_instance.each_line
    #   xsd.validate(parsed_doc).each do |error|
    #     extract = lines.take(error.line).last(5) rescue "no extract"
    #     errors << {line: error.line, message: error.message, extract: extract}
    #   end
    # rescue Nokogiri::XML::SyntaxError => e
    #   errors << "caught exception: #{e}"
    # end
    #
    puts "=" * 99
    puts "xbrl schema valid"
    puts "=" * 99
    errors
  end

  def xbrl_spec_rules(params, errors)
    puts "=" * 99
    puts "xbrl spec rules validation complete"
    puts "=" * 99
    errors
  end

  def custom_rules(params, errors)
    puts "=" * 99
    puts "xbrl spec custom rules validation complete"
    puts "=" * 99
    errors
  end
end


