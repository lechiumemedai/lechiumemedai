require "spec_helper"

describe PgSearch::Features::DMetaphone do
  describe "#rank" do
    with_model :Model do
      table do |t|
        t.string :name
        t.text :content
      end
    end

    it "returns an expression similar to a TSearch, but wraps the arguments in pg_search_dmetaphone()" do
      query = "query"
      columns = [
        PgSearch::Configuration::Column.new(:name, nil, Model),
        PgSearch::Configuration::Column.new(:content, nil, Model),
      ]
      options = {}
      config = stub(:config, :ignore => [])
      normalizer = PgSearch::Normalizer.new(config)

      feature = described_class.new(query, options, columns, Model, normalizer)
      feature.rank.to_sql.should ==
        %Q{(ts_rank((to_tsvector('simple', pg_search_dmetaphone(coalesce(#{Model.quoted_table_name}."name"::text, ''))) || to_tsvector('simple', pg_search_dmetaphone(coalesce(#{Model.quoted_table_name}."content"::text, '')))), (to_tsquery('simple', ''' ' || pg_search_dmetaphone('query') || ' ''')), 0))}
    end
  end

  describe "#conditions" do
    with_model :Model do
      table do |t|
        t.string :name
        t.text :content
      end
    end

    it "returns an expression similar to a TSearch, but wraps the arguments in pg_search_dmetaphone()" do
      query = "query"
      columns = [
        PgSearch::Configuration::Column.new(:name, nil, Model),
        PgSearch::Configuration::Column.new(:content, nil, Model),
      ]
      options = {}
      config = stub(:config, :ignore => [])
      normalizer = PgSearch::Normalizer.new(config)

      feature = described_class.new(query, options, columns, Model, normalizer)
      feature.conditions.to_sql.should ==
        %Q{((to_tsvector('simple', pg_search_dmetaphone(coalesce(#{Model.quoted_table_name}."name"::text, ''))) || to_tsvector('simple', pg_search_dmetaphone(coalesce(#{Model.quoted_table_name}."content"::text, '')))) @@ (to_tsquery('simple', ''' ' || pg_search_dmetaphone('query') || ' ''')))}
    end
  end
end
