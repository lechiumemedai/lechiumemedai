require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe PgSearch do
  context "joining to another table" do
    if defined?(ActiveRecord::Relation)
      context "with Arel support" do
        context "without an :against" do
          with_model :associated_model do
            table do |t|
              t.string "title"
            end
          end

          with_model :model_without_against do
            table do |t|
              t.string "title"
              t.belongs_to :another_model
            end

            model do
              include PgSearch
              belongs_to :another_model, :class_name => 'AssociatedModel'

              pg_search_scope :with_another, :associated_against => {:another_model => :title}
            end
          end

          it "returns rows that match the query in the columns of the associated model only" do
            associated = associated_model.create!(:title => 'abcdef')
            included = [
              model_without_against.create!(:title => 'abcdef', :another_model => associated),
              model_without_against.create!(:title => 'ghijkl', :another_model => associated)
            ]
            excluded = [
              model_without_against.create!(:title => 'abcdef')
            ]

            results = model_without_against.with_another('abcdef')
            results.map(&:title).should =~ included.map(&:title)
            results.should_not include(excluded)
          end
        end

        context "through a belongs_to association" do
          with_model :associated_model do
            table do |t|
              t.string 'title'
            end
          end

          with_model :model_with_belongs_to do
            table do |t|
              t.string 'title'
              t.belongs_to 'another_model'
            end

            model do
              include PgSearch
              belongs_to :another_model, :class_name => 'AssociatedModel'

              pg_search_scope :with_associated, :against => :title, :associated_against => {:another_model => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            associated = associated_model.create!(:title => 'abcdef')
            included = [
              model_with_belongs_to.create!(:title => 'ghijkl', :another_model => associated),
              model_with_belongs_to.create!(:title => 'abcdef')
            ]
            excluded = model_with_belongs_to.create!(:title => 'mnopqr',
                                                     :another_model => associated_model.create!(:title => 'stuvwx'))

            results = model_with_belongs_to.with_associated('abcdef')
            results.map(&:title).should =~ included.map(&:title)
            results.should_not include(excluded)
          end
        end

        context "through a has_many association" do
          with_model :associated_model_with_has_many do
            table do |t|
              t.string 'title'
              t.belongs_to 'model_with_has_many'
            end
          end

          with_model :model_with_has_many do
            table do |t|
              t.string 'title'
            end

            model do
              include PgSearch
              has_many :other_models, :class_name => 'AssociatedModelWithHasMany', :foreign_key => 'model_with_has_many_id'

              pg_search_scope :with_associated, :against => [:title], :associated_against => {:other_models => :title}
            end
          end

          it "returns rows that match the query in either its own columns or the columns of the associated model" do
            included = [
              model_with_has_many.create!(:title => 'abcdef', :other_models => [
                                          associated_model_with_has_many.create!(:title => 'foo'),
                                          associated_model_with_has_many.create!(:title => 'bar')
            ]),
              model_with_has_many.create!(:title => 'ghijkl', :other_models => [
                                          associated_model_with_has_many.create!(:title => 'foo bar'),
                                          associated_model_with_has_many.create!(:title => 'mnopqr')
            ]),
              model_with_has_many.create!(:title => 'foo bar')
            ]
            excluded = model_with_has_many.create!(:title => 'stuvwx', :other_models => [
                                                   associated_model_with_has_many.create!(:title => 'abcdef')
            ])

            results = model_with_has_many.with_associated('foo bar')
            results.map(&:title).should =~ included.map(&:title)
            results.should_not include(excluded)
          end
        end

        context "across multiple associations" do
          context "on different tables" do
            with_model :first_associated_model do
              table do |t|
                t.string 'title'
                t.belongs_to 'model_with_many_associations'
              end
              model {}
            end

            with_model :second_associated_model do
              table do |t|
                t.string 'title'
              end
              model {}
            end

            with_model :model_with_many_associations do
              table do |t|
                t.string 'title'
                t.belongs_to 'model_of_second_type'
              end

              model do
                include PgSearch
                has_many :models_of_first_type, :class_name => 'FirstAssociatedModel', :foreign_key => 'model_with_many_associations_id'
                belongs_to :model_of_second_type, :class_name => 'SecondAssociatedModel'

                pg_search_scope :with_associated, :against => :title,
                  :associated_against => {:models_of_first_type => :title, :model_of_second_type => :title}
              end
            end

            it "returns rows that match the query in either its own columns or the columns of the associated model" do
              matching_second = second_associated_model.create!(:title => "foo bar")
              unmatching_second = second_associated_model.create!(:title => "uiop")

              included = [
                ModelWithManyAssociations.create!(:title => 'abcdef', :models_of_first_type => [
                                                  first_associated_model.create!(:title => 'foo'),
                                                  first_associated_model.create!(:title => 'bar')
              ]),
                ModelWithManyAssociations.create!(:title => 'ghijkl', :models_of_first_type => [
                                                  first_associated_model.create!(:title => 'foo bar'),
                                                  first_associated_model.create!(:title => 'mnopqr')
              ]),
                ModelWithManyAssociations.create!(:title => 'foo bar'),
                ModelWithManyAssociations.create!(:title => 'qwerty', :model_of_second_type => matching_second)
              ]
              excluded = [
                ModelWithManyAssociations.create!(:title => 'stuvwx', :models_of_first_type => [
                                                  first_associated_model.create!(:title => 'abcdef')
              ]),
                ModelWithManyAssociations.create!(:title => 'qwerty', :model_of_second_type => unmatching_second)
              ]

              results = ModelWithManyAssociations.with_associated('foo bar')
              results.map(&:title).should =~ included.map(&:title)
              excluded.each { |object| results.should_not include(object) }
            end
          end

          context "on the same table" do
            with_model :doubly_associated_model do
              table do |t|
                t.string 'title'
                t.belongs_to 'model_with_double_association'
                t.belongs_to 'model_with_double_association_again'
              end
              model {}
            end

            with_model :model_with_double_association do
              table do |t|
                t.string 'title'
              end

              model do
                include PgSearch
                has_many :things, :class_name => 'DoublyAssociatedModel', :foreign_key => 'model_with_double_association_id'
                has_many :thingamabobs, :class_name => 'DoublyAssociatedModel', :foreign_key => 'model_with_double_association_again_id'

                pg_search_scope :with_associated, :against => :title,
                  :associated_against => {:things => :title, :thingamabobs => :title}
              end
            end

            it "returns rows that match the query in either its own columns or the columns of the associated model" do
              included = [
                ModelWithDoubleAssociation.create!(:title => 'abcdef', :things => [
                                                      DoublyAssociatedModel.create!(:title => 'foo'),
                                                      DoublyAssociatedModel.create!(:title => 'bar')
              ]),
                ModelWithDoubleAssociation.create!(:title => 'ghijkl', :things => [
                                                      DoublyAssociatedModel.create!(:title => 'foo bar'),
                                                      DoublyAssociatedModel.create!(:title => 'mnopqr')
              ]),
                ModelWithDoubleAssociation.create!(:title => 'foo bar'),
                ModelWithDoubleAssociation.create!(:title => 'qwerty', :thingamabobs => [
                                                      DoublyAssociatedModel.create!(:title => "foo bar")
              ])
              ]
              excluded = [
                ModelWithDoubleAssociation.create!(:title => 'stuvwx', :things => [
                                                      DoublyAssociatedModel.create!(:title => 'abcdef')
              ]),
                ModelWithDoubleAssociation.create!(:title => 'qwerty', :thingamabobs => [
                                                      DoublyAssociatedModel.create!(:title => "uiop")
              ])
              ]

              results = ModelWithDoubleAssociation.with_associated('foo bar')
              results.map(&:title).should =~ included.map(&:title)
              excluded.each { |object| results.should_not include(object) }
            end
          end
        end
        
        context "against multiple attributes on one association" do
          with_model :associated_model do
            table do |t|
              t.string 'title'
              t.text 'author'
            end
          end

          with_model :model_with_association do
            table do |t|
              t.belongs_to 'another_model'
            end

            model do
              include PgSearch
              belongs_to :another_model, :class_name => 'AssociatedModel'

              pg_search_scope :with_associated, :associated_against => {:another_model => [:title, :author]}
            end
          end
          
          it "should only do one join" do
            included = [
              ModelWithAssociation.create!(
                :another_model => AssociatedModel.create!(
                  :title => "foo",
                  :author => "bar"
                )
              ),
              ModelWithAssociation.create!(
                :another_model => AssociatedModel.create!(
                  :title => "foo bar",
                  :author => "baz"
                )
              )
            ]
            excluded = [
              ModelWithAssociation.create!(
                :another_model => AssociatedModel.create!(
                  :title => "foo",
                  :author => "baz"
                )
              )
            ]

            results = ModelWithAssociation.with_associated('foo bar')

            results.to_sql.scan("INNER JOIN").length.should == 1
            included.each { |object| results.should include(object) }
            excluded.each { |object| results.should_not include(object) }
          end
          
        end
      end
    else
      context "without Arel support" do
        with_model :model do
          table do |t|
            t.string 'title'
          end

          model do
            include PgSearch
            pg_search_scope :with_joins, :against => :title, :joins => :another_model
          end
        end

        it "should raise an error" do
          lambda {
            Model.with_joins('foo')
          }.should raise_error(ArgumentError, /joins/)
        end
      end
    end
  end
end
