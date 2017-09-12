require 'date'

class Converter

  def initialize(ixbrl_doc)
    @ixbrl_doc = ixbrl_doc
  end

  def to_xbrl
    # ixbrl attributes need to be stripped from facts
    excluded_attributes = ["name", "scale", "format", "order", "tupleRef", "tupleID", "sign"]
    @tuple_lookup = {}

    # extract relevant sections
    schema_ref = @ixbrl_doc.search('link|schemaRef')
    units = @ixbrl_doc.search('xbrli|unit')
    facts = @ixbrl_doc.search("ix|nonNumeric", "ix|nonFraction")
    tuples = @ixbrl_doc.search("ix|tuple")
    contexts = @ixbrl_doc.search("xbrli|context")

    # build base xbrl document from ixbrl file
    namespaces = @ixbrl_doc.collect_namespaces
    xbrl_base = Nokogiri::XML::Builder.new { |xml| xml['xbrli'].xbrl(namespaces) }
    @xbrl_doc = Nokogiri.XML(xbrl_base.to_xml)

    # Add schemaRef
    schema_ref_node = schema_ref.first.clone
    @xbrl_doc.root.add_child(schema_ref_node)

    # keep track of the insert point
    insert_node = schema_ref_node

    # Add units
    units.each do |unit|
      unit_node = unit.clone
      insert_node.add_next_sibling(unit_node)
      insert_node = unit_node
    end

    # Add contexts
    contexts.each do |context|
      context_node = context.clone
      insert_node.add_next_sibling(context_node)
      insert_node = context_node
    end

    # Add tuples
    tuples.each do |tuple|
      tuple_node = @xbrl_doc.create_element(tuple.attributes["name"].value, tuple.content)
      insert_node.add_next_sibling(tuple_node)
      insert_node = tuple_node
      # for looking up tuple parents when adding facts
      @tuple_lookup[tuple.attributes["tupleID"].value] = tuple_node
    end

    # Add facts
    facts.each do |fact|
      # format per ixbrl tranform rules
      content = formatted_content(fact)
      fact_node = @xbrl_doc.create_element(fact.attributes["name"].value, content)
      # add applicable attributes
      fact.attributes.reject { |k,v| excluded_attributes.include?(k) }.each { |k,v| fact_node[k] = v }
      # If fact is a tuple item append to parent
      if tuple = tuple_parent(fact)
        tuple.add_child(fact_node)
      else
        insert_node.add_next_sibling(fact_node)
        insert_node = fact_node
      end
    end

    # Save file to disk to debug
    File.open('xbrl.xml', 'w') { |file| file.write(@xbrl_doc.to_xml) }

    # return xml
    @xbrl_doc.to_xml
  end

  def tuple_parent(fact)
    return nil unless fact.attributes.has_key?("tupleRef")
    id = fact.attributes["tupleRef"].value
    @tuple_lookup[id]
  end

  def formatted_content(fact)
    content = fact.content # doesnt seem to be stripped 
    format = fact.attributes["format"]&.value

    # remove content of ix:excludes nodes
    if fact.children.any?
      fact.children.select { |f| f.name == "exclude" }.map(&:content).each do |substr|
        content = content.gsub(substr, '')
      end
    end 

    content.strip 

    # format strings
    if format == "ixt:numcommadot"
      num = content.gsub(/\(/, "-").gsub(/\,|\)/, "").to_i
      # if sign attr present number should be negated
      fact.attributes["sign"]&.value == '-1' ? (num * -1) : num
    elsif format == "ixt:datelonguk"
      DateTime.parse(content).strftime('%Y-%m-%d')
    else
      content
    end
  end
end