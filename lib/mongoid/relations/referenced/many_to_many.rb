# encoding: utf-8
module Mongoid # :nodoc:
  module Relations #:nodoc:
    module Referenced #:nodoc:

      # This class defines the behaviour for all relations that are a
      # many-to-many between documents in different collections.
      class ManyToMany < Referenced::Many

        # Delete a single document from the relation.
        #
        # @example Delete a document.
        #   person.preferences.delete(preference)
        #
        # @param [ Document ] document The document to delete.
        #
        # @since 2.0.0.rc.1
        def delete(document, options = {})
          target.delete(document).tap do |doc|
            binding.unbind_one(doc, default_options.merge!(options)) if doc
          end
        end

        # Deletes all related documents from the database given the supplied
        # conditions.
        #
        # @example Delete all documents in the relation.
        #   person.preferences.delete_all
        #
        # @example Conditonally delete all documents in the relation.
        #   person.preferences.delete_all(:conditions => { :title => "Testing" })
        #
        # @param [ Hash ] conditions Optional conditions to delete with.
        #
        # @return [ Integer ] The number of documents deleted.
        def delete_all(conditions = nil)
          selector = (conditions || {})[:conditions] || {}
          target.delete_if { |doc| doc.matches?(selector) }
          scoping = { :_id => { "$in" => base.send(metadata.foreign_key) } }
          metadata.klass.delete_all(:conditions => selector.merge(scoping))
        end

        # Destroys all related documents from the database given the supplied
        # conditions.
        #
        # @example Destroy all documents in the relation.
        #   person.preferences.destroy_all
        #
        # @example Conditonally destroy all documents in the relation.
        #   person.preferences.destroy_all(:conditions => { :title => "Testing" })
        #
        # @param [ Hash ] conditions Optional conditions to destroy with.
        #
        # @return [ Integer ] The number of documents destroyd.
        def destroy_all(conditions = nil)
          selector = (conditions || {})[:conditions] || {}
          target.delete_if { |doc| doc.matches?(selector) }
          scoping = { :_id => { "$in" => base.send(metadata.foreign_key) } }
          metadata.klass.destroy_all(:conditions => selector.merge(scoping))
        end

        # Find the matchind document on the association, either based on id or
        # conditions.
        #
        # @example Find by an id.
        #   person.preferences.find(BSON::ObjectId.new)
        #
        # @example Find by multiple ids.
        #   person.preferences.find([ BSON::ObjectId.new, BSON::ObjectId.new ])
        #
        # @example Conditionally find all matching documents.
        #   person.preferences.find(:all, :conditions => { :title => "Sir" })
        #
        # @example Conditionally find the first document.
        #   person.preferences.find(:first, :conditions => { :title => "Sir" })
        #
        # @example Conditionally find the last document.
        #   person.preferences.find(:last, :conditions => { :title => "Sir" })
        #
        # @param [ Symbol, BSON::ObjectId, Array<BSON::ObjectId> ] arg The
        #   argument to search with.
        # @param [ Hash ] options The options to search with.
        #
        # @return [ Document, Criteria ] The matching document(s).
        def find(arg, options = {})
          klass = metadata.klass
          return klass.criteria.id_criteria(arg) unless arg.is_a?(Symbol)
          selector = (options[:conditions] || {}).merge(
            "_id" => { "$in" => base.send(metadata.foreign_key) }
          )
          klass.find(arg, :conditions => selector)
        end

        # Removes all associations between the base document and the target
        # documents by deleting the foreign keys and the references, orphaning
        # the target documents in the process.
        #
        # @example Nullify the relation.
        #   person.preferences.nullify
        #
        # @since 2.0.0.rc.1
        def nullify
          load! and target.each do |doc|
            base.send(metadata.foreign_key).delete(doc.id)
            dereference(doc)
          end
          target.clear
        end
        alias :nullify_all :nullify

        # Substitutes the supplied target documents for the existing documents
        # in the relation. If the new target is nil, perform the necessary
        # deletion.
        #
        # @example Replace the relation.
        #   person.posts.substitute(new_name)
        #
        # @param [ Array<Document> ] target The replacement target.
        # @param [ Hash ] options The options to bind with.
        #
        # @option options [ true, false ] :binding Are we in build mode?
        # @option options [ true, false ] :continue Continue binding the
        #   inverse?
        #
        # @return [ Many ] The relation.
        #
        # @since 2.0.0.rc.1
        def substitute(new_target, options = {})
          tap do |relation|
            if new_target
              binding.unbind(options)
              relation.target = new_target.to_a
              bind(options)
            else
              relation.target = unbind(options)
            end
          end
        end

        # Unbinds the base object to the inverse of the relation. This occurs
        # when setting a side of the relation to nil.
        #
        # Will delete the object if necessary.
        #
        # @example Unbind the target.
        #   person.posts.unbind
        #
        # @param [ Hash ] options The options to bind with.
        #
        # @option options [ true, false ] :binding Are we in build mode?
        # @option options [ true, false ] :continue Continue binding the
        #   inverse?
        #
        # @since 2.0.0.rc.1
        def unbind(options = {})
          target.each(&:delete) if base.persisted?
          binding.unbind(options)
          []
        end

        private

        # Instantiate the binding associated with this relation.
        #
        # @example Get the binding.
        #   relation.binding([ address ])
        #
        # @param [ Array<Document> ] new_target The new documents to bind with.
        #
        # @return [ Binding ] The binding.
        #
        # @since 2.0.0.rc.1
        def binding(new_target = nil)
          Bindings::Referenced::ManyToMany.new(base, new_target || target, metadata)
        end

        # Returns the criteria object for the target class with its documents set
        # to target.
        #
        # @example Get a criteria for the relation.
        #   relation.criteria
        #
        # @return [ Criteria ] A new criteria.
        def criteria
          metadata.klass.any_in(metadata.inverse_foreign_key => [ base.id ])
        end

        # Dereferences the supplied document from the base of the relation.
        #
        # @example Dereference the document.
        #   person.preferences.dereference(preference)
        #
        # @param [ Document ] document The document to dereference.
        def dereference(document)
          document.send(metadata.inverse_foreign_key).delete(base.id)
          document.send(metadata.inverse(document)).target.delete(base)
          document.save
        end

        class << self

          # Return the builder that is responsible for generating the documents
          # that will be used by this relation.
          #
          # @example Get the builder.
          #   Referenced::ManyToMany.builder(meta, object)
          #
          # @param [ Metadata ] meta The metadata of the relation.
          # @param [ Document, Hash ] object A document or attributes to build
          #   with.
          #
          # @return [ Builder ] A new builder object.
          #
          # @since 2.0.0.rc.1
          def builder(meta, object)
            Builders::Referenced::ManyToMany.new(meta, object)
          end

          # Returns true if the relation is an embedded one. In this case
          # always false.
          #
          # @example Is this relation embedded?
          #   Referenced::ManyToMany.embedded?
          #
          # @return [ false ] Always false.
          #
          # @since 2.0.0.rc.1
          def embedded?
            false
          end

          # Get the default value for the foreign key.
          #
          # @example Get the default.
          #   Referenced::ManyToMany.foreign_key_default
          #
          # @return [ Array ] Always an empty array.
          #
          # @since 2.0.0.rc.1
          def foreign_key_default
            []
          end

          # Returns the suffix of the foreign key field, either "_id" or "_ids".
          #
          # @example Get the suffix for the foreign key.
          #   Referenced::ManyToMany.foreign_key_suffix
          #
          # @return [ String ] "_ids"
          #
          # @since 2.0.0.rc.1
          def foreign_key_suffix
            "_ids"
          end

          # Returns the macro for this relation. Used mostly as a helper in
          # reflection.
          #
          # @example Get the macro.
          #   Referenced::ManyToMany.macro
          #
          # @return [ Symbol ] :references_and_referenced_in_many
          def macro
            :references_and_referenced_in_many
          end

          # Return the nested builder that is responsible for generating the documents
          # that will be used by this relation.
          #
          # @example Get the nested builder.
          #   Referenced::ManyToMany.builder(attributes, options)
          #
          # @param [ Metadata ] metadata The relation metadata.
          # @param [ Hash ] attributes The attributes to build with.
          # @param [ Hash ] options The options for the builder.
          #
          # @option options [ true, false ] :allow_destroy Can documents be
          #   deleted?
          # @option options [ Integer ] :limit Max number of documents to
          #   create at once.
          # @option options [ Proc, Symbol ] :reject_if If documents match this
          #   option then they are ignored.
          # @option options [ true, false ] :update_only Only existing documents
          #   can be modified.
          #
          # @return [ NestedBuilder ] A newly instantiated nested builder object.
          #
          # @since 2.0.0.rc.1
          def nested_builder(metadata, attributes, options)
            Builders::NestedAttributes::Many.new(metadata, attributes, options)
          end

          # Tells the caller if this relation is one that stores the foreign
          # key on its own objects.
          #
          # @example Does this relation store a foreign key?
          #   Referenced::Many.stores_foreign_key?
          #
          # @return [ true ] Always true.
          #
          # @since 2.0.0.rc.1
          def stores_foreign_key?
            true
          end
        end
      end
    end
  end
end
