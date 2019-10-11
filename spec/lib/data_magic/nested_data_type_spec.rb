require 'spec_helper'
require 'data_magic'
require 'hashie'

describe DataMagic::QueryBuilder do

  before :example do
    DataMagic.destroy
    DataMagic.client
    ENV['DATA_PATH'] = './spec/fixtures/nested_data_type'
    DataMagic.config = DataMagic::Config.new
  end

  after :example do
    DataMagic.destroy
  end

  RSpec.configure do |c|
    c.alias_it_should_behave_like_to :it_correctly, 'correctly:'
  end

  let(:nested_meta) { { post_es_response: {}, from: 0, size: 20, _source: false } }
  let(:options) { {} }
  let(:query_hash) { DataMagic::QueryBuilder.from_params(subject, options, DataMagic.config) }

  shared_examples "builds a query" do
    it "with a query section" do
      expect(query_hash[:query]).to eql expected_query
    end
    it "with query metadata" do
        expect(query_hash.reject { |k, _| k == :query }).to eql nested_meta
    end
  end

  describe "builds queries based on nested datatype fields" do
    context "in absence of all_programs param" do
      subject { { "2016.programs.cip_4_digit" => "1312" } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  query: {
                      bool: {
                          must: [{
                              match: { "2016.programs.cip_4_digit" => "1312" }
                          }]
                      }
                  }
              }
          } } } 
      }
      it_correctly "builds a query"
    end

    context "in presence of all_programs param" do
      subject {{ "2016.programs.cip_4_digit" => "1312" }}
      let(:options) {{ :all_programs => true }}

      let(:expected_query) {{ match: { "2016.programs.cip_4_digit" => "1312" }} }
      let(:nested_meta)    {{ post_es_response: {}, from: 0, size: 20, _source: {:exclude=>["_*"]} } }

      it_correctly "builds a query"
    end
  end

  describe "builds queries that correctly handle fields in params" do
    context "no fields are passed in the params" do
      subject {{}}
      let(:options) {{}}
      let(:source_value) { {:exclude=>["_*"]} }

      it "assigns a Hash with key 'exclude' to _source" do
        expect(query_hash[:_source]).to eql source_value
      end
    end

    context "only non-nested datatype fields are passed in params" do
      subject {{}}
      let(:fields_in_params) { ["school.name","id"] }
      let(:options) {{ :fields => fields_in_params }}
      let(:source_value) { false }

      it "assigns 'false' to _source" do
        expect(query_hash[:_source]).to eql source_value
      end

      it "assigns the fields to the query fields key" do
        expect(query_hash[:fields]).to eql fields_in_params
      end
    end

    
    context "only nested datatype fields are passed in params" do
      context "the query is NOT a nested query type" do
        subject {{}}
        let(:fields_in_params) { ["2016.programs.cip_4_digit.code"] }
        let(:options) {{ :fields => fields_in_params }}

        it "assigns the fields to _source" do
          expect(query_hash[:_source]).to eql fields_in_params
        end

        it "query fields key is empty" do
          expect(query_hash[:fields]).to be_nil
        end
      end

      context "the query is a nested query type" do
        subject {{ "2016.programs.cip_4_digit" => "1312" }}
        let(:fields_in_params) { ["2016.programs.cip_4_digit.code"] }
        let(:options) {{ :fields => fields_in_params }}
        let(:source_value) { false }

        it "assigns false to _source" do
          expect(query_hash[:_source]).to eql source_value
        end

        it "query fields key is empty" do
          expect(query_hash[:fields]).to be_nil
        end

        it "passes the nested fields to the query hash post_es_response key" do
          expect(query_hash[:post_es_response][:nested_fields_filter]).to eql fields_in_params
        end
      end
    end
  end
end