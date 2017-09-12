ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'nokogiri'
require_relative '../lib/converter'

class ConverterTests < MiniTest::Test

  def setup 
    ixbrl_doc = Nokogiri::XML(File.open(File.join(__dir__, 'ixbrl-doc.html')))
    xbrl_xml = Converter.new(ixbrl_doc).to_xbrl
    @xbrl_doc = Nokogiri::XML(xbrl_xml)
  end

  def test_root
    node = @xbrl_doc.search('xbrli|xbrl').first
    refute_nil node, "root node present"
  end

  def test_namespaces
    namespaces = [
      "http://www.w3.org/1999/xhtml", "http://www.xbrl-ie.net/common/core/2012-12-01",
      "http://www.xbrl-ie.net/gaap/core/2012-12-01", "http://www.xbrl.org/2003/iso4217",
      "http://www.xbrl.org/2008/inlineXBRL", "http://www.xbrl.org/inlineXBRL/transformation/2010-04-20",
      "http://www.xbrl.org/2003/linkbase", "http://www.xbrl.org/uk/reports/aurep/2009-09-01",
      "http://www.xbrl.org/uk/cd/business/2009-09-01", "http://www.xbrl.org/uk/cd/countries/2009-09-01",
      "http://www.xbrl.org/uk/reports/direp/2009-09-01", "http://www.xbrl.org/uk/gaap/core/2009-09-01",
      "http://xbrl.org/2006/xbrldi", "http://www.xbrl.org/2003/instance",
      "http://www.w3.org/1999/xlink","http://www.w3.org/2001/XMLSchema-instance"
    ]
    assert_empty @xbrl_doc.collect_namespaces.values - namespaces, "namespaces present"
  end

  def test_schema
    node = @xbrl_doc.search('link|schemaRef').first
    refute_nil node, "schema node present"
  end

  def test_units
    nodes = @xbrl_doc.search('xbrli|unit')
    assert_equal nodes.length, 4, "unit node present"
  end

  def test_tuples
     node = @xbrl_doc.search('uk-bus|XBRLDocumentAuthorGrouping').first
     assert_empty node.elements.map(&:name) - ["NameAuthor", "DescriptionOrTitleAuthor"], "item added to tuple"
  end

  def test_facts
    node = @xbrl_doc.search("uk-direp|DirectorSigningReport").first
    assert_empty node.content, "exclude tag content should be excluded"

    node = @xbrl_doc.search("uk-direp|DateSigningDirectorsReport").first
    assert_equal "2017-07-18", node.content, "data tranformed correctly"

    node = @xbrl_doc.search("uk-gaap|DescriptionSignificantChangeInActivitiesDuringPeriod").first
    assert_equal node.content.strip, "No changes.", "Non numeric parsed correctly"
   
    nodes = @xbrl_doc.search("uk-gaap|OperatingProfitLoss")
    assert_equal nodes.map(&:content), ["2000", "-2000"], "Numeric values tranformed correctly"
  end
end