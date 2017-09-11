class Converter

  def initialize(ixbrl_doc)
    @ixbrl_doc = ixbrl_doc
    xbrl_base_file = File.open('xbrl-base.xml')
    @xbrl_doc = Nokogiri::XML(xbrl_base_file)
  end

  def to_xbrl
    ixbrl_nodes = @doc.xpath("//*[namespace-uri()='http://www.xbrl.org/2008/inlineXBRL']")
    xbrl_nodes = @doc.xpath("//*[namespace-uri()='http://www.xbrl.org/2003/instance']")

    insert_node = @xbrl_doc.search('xbrli|unit').last

    xbrl_nodes.each do |xbrli_node|
      insert_node.add_next_sibling(xbrli_node)
    end

    start_node = @xbrl_doc.search('xbrli|context').last

    ixbrl_nodes.each do |ix_node|
      next if ix_node.name == "exclude"
      if ix_node.attributes.has_key?("name")
        fact = @xbrl_doc.create_element(ix_node.attributes["name"], ix_node.content)
        ix_node.attributes
          .delete_if {|k, v| ["name", "format", "scale"].include?(k) }
          .each { |k,v| fact[k] = v }
        insert_node.add_next_sibling(fact)
      end
    end

    @xbrl_doc
  end
end