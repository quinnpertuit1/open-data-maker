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

  describe "builds queries with on nested datatype fields depending on options passed" do
    context "in absence of all_programs param" do
      subject { { "2016.programs.cip_4_digit.code" => "1312" } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  query: {
                      bool: {
                          must: [{
                              match: { "2016.programs.cip_4_digit.code" => "1312" }
                          }]
                      }
                  }
              }
          } } } 
      }
      it_correctly "builds a query"
    end

    context "in presence of all_programs param" do
      subject {{ "2016.programs.cip_4_digit.code" => "1312" }}
      let(:options) {{ :all_programs => true }}

      let(:expected_query) {{ match: { "2016.programs.cip_4_digit.code" => "1312" }} }
      let(:nested_meta)    {{ post_es_response: {}, from: 0, size: 20, _source: {:exclude=>["_*"]} } }

      it_correctly "builds a query"
    end

    context "in presence of all_programs_nested param" do
      subject {{ "2016.programs.cip_4_digit.code" => "1312" }}
      let(:options) {{ :all_programs_nested => true, :fields => ["2016.programs.cip_4_digit.code.earnings.median_earnings"] }}

      let(:expected_query) { 
        { bool: { filter: {
            nested: {
                inner_hits: {},
                path: "2016.programs.cip_4_digit",
                query: {
                    bool: {
                        must: [{
                            match: { "2016.programs.cip_4_digit.code" => "1312" }
                        }]
                    }
                }
            }
        } } } 
      }
      let(:nested_meta) {{
        post_es_response: {:nested_fields_filter=>["2016.programs.cip_4_digit.code.earnings.median_earnings"]},
        from: 0,
        size: 20,
        _source: ["2016.programs.cip_4_digit.code.earnings.median_earnings"]
      }}

      it_correctly "builds a query"
    end
  end

  describe "builds correct nested query objects depending on terms passed" do
    context "for a single nested datatype query that takes an array of values" do
      subject { { "2016.programs.cip_4_digit.credential.level" => "[2,3,5]" } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  filter: [
                    { "terms": { "2016.programs.cip_4_digit.credential.level" => [2, 3, 5]} }
                  ]
              }
          } } } 
      }
      it_correctly "builds a query"
    end

    context "when more than one terms and each term has a single value" do
      subject { { 
        "2016.programs.cip_4_digit.code" => "1312",
        "2016.programs.cip_4_digit.credential.level" => "2",
      } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  query: {
                      bool: {
                          must: [
                            { match: { "2016.programs.cip_4_digit.code" => "1312" }},
                            { match: { "2016.programs.cip_4_digit.credential.level" => "2" }}
                          ]
                      }
                  }
              }
          } } } 
      }
      it_correctly "builds a query"
      
    end

    context "when more than one term and each term takes an array of values" do
      subject { { 
        "2016.programs.cip_4_digit.credential.level" => "[2,3,5]",
        "2016.programs.cip_4_digit.code" => "[1312,4004]",
      } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  filter: [
                    { "terms": { "2016.programs.cip_4_digit.credential.level" => [2, 3, 5]} },
                    { "terms": { "2016.programs.cip_4_digit.code" => [1312,4004]} }
                  ]
              }
          } } } 
      }
      it_correctly "builds a query"
    end

    context "when one term has an array of values and the other has a single value" do
      subject { { 
        "2016.programs.cip_4_digit.credential.level" => "[2,3,5]",
        "2016.programs.cip_4_digit.code" => "1312"
      } }
      let(:expected_query) { 
        { bool: { filter: {
            nested: {
              inner_hits: {},
              path: "2016.programs.cip_4_digit",
              query: {
                bool: {
                  filter: [
                    { terms: { "2016.programs.cip_4_digit.credential.level" => [2, 3, 5]} },
                    { match: { "2016.programs.cip_4_digit.code" => "1312" }}
                  ]
                }
              }
            }
        } } } 
      }
      it_correctly "builds a query"
      
    end
  end


  describe "builds nested filter queries for terms that accept an array of values" do
    context "for a single nested datatype query term" do
      subject { { "2016.programs.cip_4_digit.credential.level" => "[2,3,5]" } }
      let(:expected_query) { 
          { bool: { filter: {
              nested: {
                  inner_hits: {},
                  path: "2016.programs.cip_4_digit",
                  filter: [
                    { "terms": { "2016.programs.cip_4_digit.credential.level" => [2, 3, 5]} }
                  ]
              }
          } } } 
      }
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
        let(:fields_in_params) { ["2016.programs.cip_4_digit.code.code"] }
        let(:options) {{ :fields => fields_in_params }}

        it "assigns the fields to _source" do
          expect(query_hash[:_source]).to eql fields_in_params
        end

        it "query fields key is empty" do
          expect(query_hash[:fields]).to be_nil
        end
      end

      context "the query is a nested query type" do
        subject {{ "2016.programs.cip_4_digit.code" => "1312" }}
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