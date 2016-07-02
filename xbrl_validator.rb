require 'sinatra'
require 'nokogiri'
require 'json'

configure { set :server, :puma }

get '/' do
  'Hello world!'
end

post '/validate' do
  instance = params["xbrl_instance"]
  [200, validate_xbrl_document(instance)]
end

def validate_xbrl_document(instance)
  errors = []
  xbrl_doc = instance

  # Pipline as follows (xhtml):
  #   - xml well formed
  #   - schema valid (ixbrl and xhtml schemas)
  #   - taxonomy reference check (just revenue / cro schemaRef)
  #   - ixbrl specification rules (inline XBRL specification rules. These take the form of ‘Schematron’ rules)
  # (xbrl):
  #   - DTS discovery (checks tags are included in taxonomies)
  #   - schema valid (xbrl instance schema)
  #   - xbrl spec rules (xbrl 2.1 specification rules and dimension validation)
  #   - custom rules set out by revenue (contact for full list i guess)

  begin
    doc = Nokogiri::XML(xbrl_doc) { |config| config.strict }
    xsd_entry_file = "xsd/ie/ie-gaap-main-2012-12-01.xsd"
    xsd = Nokogiri::XML::Schema(File.open(xsd_entry_file))
    lines = xbrl_doc.each_line
    puts "=" * 99
    puts lines.count
    puts "=" * 99
    xsd.validate(doc).each do |error|
      # extract = lines.take(error.line).last(5)
      errors << {line: error.line, message: error.message, extract: ""}
    end
  rescue Nokogiri::XML::SyntaxError => e
    errors << "caught exception: #{e}"
  end
  puts "=" * 99
  puts errors.count
  puts "=" * 99
  errors.to_json
end
