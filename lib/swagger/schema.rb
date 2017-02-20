module Swagger
  # Represents a Swagger Schema Object, a more deterministic subset of JSON Schema.
  # @see https://github.com/wordnik/swagger-spec/blob/master/versions/2.0.md#schema-object- Schema Object
  # @see http://json-schema.org/ JSON Schema
  class Schema < Hashie::Mash
    include Attachable
    include Hashie::Extensions::MergeInitializer
    include Hashie::Extensions::DeepFind
    attr_accessor :parent

    def initialize(hash, default = nil)
      super
      attach_to_children
    end

    def parse
      schema = clone
      if schema.key?('$ref')
        key = schema.delete('$ref').split('/').last
        model = root.definitions[key]
        schema.merge!(model)
      end

      count = 0
      until schema.refs_resolved?
        fail 'Could not resolve non-remote $refs 5 cycles - circular references?' if count >= 5
        schema.resolve_refs
        count += 1
      end

      schema.to_hash
    end

    protected

    def refs
      deep_find_all('$ref')
    end

    def resolve_refs
      if key?('allOf')
        allof = delete('allOf')
        allof.each do |it|
          if it.is_a?(Swagger::Schema)
            it.attach_parent(self)
            it.resolve_refs
          end
          self.merge!(it)
        end
      end
      children.each do |child|
        child.resolve_refs if child.is_a?(Swagger::Schema)
      end
      key = self.delete('$ref')
      return if key.nil? || remote_ref?(key)
      key = key.split('/').last
      model = root.definitions[key]
      self.merge!(model)
    end

    def refs_resolved?
      return true if refs.nil?

      refs.all? do |ref|
        remote_ref?(ref)
      end
    end

    def remote_ref?(ref)
      ref.match(%r{\A\w+\://})
    end
  end
end
