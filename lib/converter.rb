require 'date'

class Converter

  def initialize(ixbrl_doc)
    @ixbrl_doc = ixbrl_doc
    xbrl_base_file = File.open('xbrl-base.xml')
    @xbrl_doc = Nokogiri::XML(xbrl_base_file)
  end

  def to_xbrl
    exclude_attributes = ["name", "scale", "format", "order", "tupleRef", "tupleID", "sign"]
    facts = @ixbrl_doc.search("ix|nonNumeric", "ix|nonFraction")
    tuples = @ixbrl_doc.search("ix|tuple")
    contexts = @ixbrl_doc.search("xbrli|context")

    context_insert_node = @xbrl_doc.search('xbrli|unit').last

    contexts.each do |context|
      copy_context = context.clone
      context_insert_node.add_next_sibling(copy_context)
    end

    fact_insert_node = @xbrl_doc.search('xbrli|context').last

    facts.each do |fact|
      next if fact.name == "exclude"
      if fact.attributes.has_key?("name")
        content = formatted_content(fact)
        node = @xbrl_doc.create_element(fact.attributes["name"], content)
        fact.attributes
          .reject {|k, v| exclude_attributes.include?(k) }
          .each { |k,v| node[k] = v }
        fact_insert_node.add_next_sibling(node)
      end
    end

    File.open('xbrl.xml', 'w') { |file| file.write(@xbrl_doc.to_xml) }
  end

  def formatted_content(fact)
    content = fact.content # doesnt seem to be stripped 
    format = fact.attributes["format"].value rescue nil

    # remove ix:excludes
    if fact.children.any?
      fact.children.select { |f| f.name == "exclude" }.map(&:content).each do |substr|
        content = content.gsub(substr, '')
      end
    end 

    content.strip

    # format strings
    if format == "ixt:numcommadot"
      content.gsub(/\(/, "-").gsub(/\,|\)/, "").to_i
    elsif format == "ixt:datelonguk"
      DateTime.parse(content).strftime('%Y-%m-%d')
    else
      content
    end
  end
end