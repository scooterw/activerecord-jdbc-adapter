require 'jdbc_common'
require 'db/mysql'
begin; require 'active_support/core_ext/numeric/bytes'; rescue LoadError; end

class DBSetup < ActiveRecord::Migration

  def self.up
    create_table :books do |t|
      t.string :title
      t.timestamps
    end

    create_table :cars, :primary_key => 'legacy_id' do |t|
      t.string :name
      t.date :production_started_on
    end

    create_table :cats, :id => false do |t|
      t.string :name
    end

    create_table :memos do |t|
      t.text :text, :limit => 16.megabytes
    end
  end

  def self.down
    drop_table :books
    drop_table :cars
    drop_table :cats
    drop_table :memos
  end

end

class MysqlInfoTest < Test::Unit::TestCase
  
  def self.startup
    DBSetup.up
  end

  def self.shutdown
    DBSetup.down
  end

  ## primary_key
  def test_should_return_the_primary_key_of_a_table
    assert_equal 'id', connection.primary_key('books')
  end

  def test_should_be_able_to_return_a_custom_primary_key
    assert_equal 'legacy_id', connection.primary_key('cars')
  end

  def test_should_return_nil_for_a_table_without_a_primary_key
    assert_nil connection.primary_key('cats')
  end

  ## structure_dump
  def test_should_include_the_tables_in_a_structure_dump
    # TODO: Improve these tests, I added this one because no other tests exists for this method.
    dump = connection.structure_dump
    assert dump.include?('CREATE TABLE `books`')
    assert dump.include?('CREATE TABLE `cars`')
    assert dump.include?('CREATE TABLE `cats`')
    assert dump.include?('CREATE TABLE `memos`')
  end

  def test_should_include_longtext_in_schema_dump
    strio = StringIO.new
    ActiveRecord::SchemaDumper::dump(connection, strio)
    dump = strio.string
    assert_match %r{t.text\s+"text",\s+:limit => 2147483647$}, dump
  end

  # JRUBY-5040
  def test_schema_dump_should_not_have_limits_on_datetime
    dump = schema_dump
    dump.lines.grep(/datetime/).each {|line| assert line !~ /limit/ }
  end

  def test_schema_dump_should_not_have_limits_on_date
    dump = schema_dump
    dump.lines.grep(/date/).each {|line| assert line !~ /limit/ }
  end

  def test_should_include_limit
    text_column = connection.columns('memos').find { |c| c.name == 'text' }
    assert_equal 2147483647, text_column.limit
  end

  def test_should_set_sqltype_to_longtext
    text_column = connection.columns('memos').find { |c| c.name == 'text' }
    assert text_column.sql_type =~ /^longtext/i
  end

  def test_should_set_type_to_text
    text_column = connection.columns('memos').find { |c| c.name == 'text' }
    assert_equal :text, text_column.type
  end

  def test_verify_url_has_options
    url = connection.config[:url]
    assert url =~ /characterEncoding=utf8/
    assert url =~ /useUnicode=true/
    assert url =~ /zeroDateTimeBehavior=convertToNull/
  end

  def test_no_limits_for_some_data_types
    DbTypeMigration.up
    #
    # AR-3.2 :
    # 
    #  create_table "db_types", :force => true do |t|
    #    t.datetime "sample_timestamp"
    #    t.datetime "sample_datetime"
    #    t.date     "sample_date"
    #    t.time     "sample_time"
    #    t.decimal  "sample_decimal",                           :precision => 15, :scale => 0
    #    t.decimal  "sample_small_decimal",                     :precision => 3,  :scale => 2
    #    t.decimal  "sample_default_decimal",                   :precision => 10, :scale => 0
    #    t.float    "sample_float"
    #    t.binary   "sample_binary"
    #    t.boolean  "sample_boolean"
    #    t.string   "sample_string",                                                           :default => ""
    #    t.integer  "sample_integer",              :limit => 8
    #    t.integer  "sample_integer_with_limit_2", :limit => 2
    #    t.integer  "sample_integer_with_limit_8", :limit => 8
    #    t.integer  "sample_integer_no_limit"
    #    t.integer  "sample_integer_neg_default",                                              :default => -1
    #    t.text     "sample_text"
    #  end
    #
    # AR-2.3 :
    # 
    #  create_table "db_types", :force => true do |t|
    #    t.datetime "sample_timestamp"
    #    t.datetime "sample_datetime"
    #    t.date     "sample_date"
    #    t.time     "sample_time"
    #    t.integer  "sample_decimal",              :limit => 15, :precision => 15, :scale => 0
    #    t.decimal  "sample_small_decimal",                      :precision => 3,  :scale => 2
    #    t.integer  "sample_default_decimal",      :limit => 10, :precision => 10, :scale => 0
    #    t.float    "sample_float"
    #    t.binary   "sample_binary"
    #    t.boolean  "sample_boolean"
    #    t.string   "sample_string",                                                            :default => ""
    #    t.integer  "sample_integer",              :limit => 8
    #    t.integer  "sample_integer_with_limit_2", :limit => 2
    #    t.integer  "sample_integer_with_limit_8", :limit => 8
    #    t.integer  "sample_integer_no_limit"
    #    t.integer  "sample_integer_neg_default",                                               :default => -1
    #    t.text     "sample_text"
    #  end
    #
    dump = schema_dump
    if ar_version('3.0')
      assert_nil dump.lines.detect {|l| l =~ /\.(float|date|datetime|integer|time|timestamp) .* :limit/ && l !~ /sample_integer/ }, dump
    else
      puts "test_no_limits_for_some_data_types assertion skipped on #{ActiveRecord::VERSION::STRING}"
    end
  ensure
    DbTypeMigration.down
  end
  
end
