# Protocol Buffers - Google's data interchange format
# Copyright 2022 Google Inc.  All rights reserved.
# https://developers.google.com/protocol-buffers/
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#     * Neither the name of Google Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module Google
  module Protobuf
    class FFI
      # Map
      attach_function :map_clear,  :upb_Map_Clear,                    [:Map], :void
      attach_function :map_delete, :upb_Map_Delete,                   [:Map, MessageValue.by_value, MessageValue.by_ref], :bool
      attach_function :map_get,    :upb_Map_Get,                      [:Map, MessageValue.by_value, MessageValue.by_ref], :bool
      attach_function :create_map, :upb_Map_New,                      [Internal::Arena, CType, CType], :Map
      attach_function :map_size,   :upb_Map_Size,                     [:Map], :size_t
      attach_function :map_set,    :upb_Map_Set,                      [:Map, MessageValue.by_value, MessageValue.by_value, Internal::Arena], :bool

      # MapIterator
      attach_function :map_next,   :upb_MapIterator_Next,             [:Map, :pointer], :bool
      attach_function :map_done,   :upb_MapIterator_Done,             [:Map, :size_t], :bool
      attach_function :map_key,    :upb_MapIterator_Key,              [:Map, :size_t], MessageValue.by_value
      attach_function :map_value,  :upb_MapIterator_Value,            [:Map, :size_t], MessageValue.by_value
    end
    class Map
      include Enumerable
      ##
      # call-seq:
      #    Map.new(key_type, value_type, value_typeclass = nil, init_hashmap = {})
      #    => new map
      #
      # Allocates a new Map container. This constructor may be called with 2, 3, or 4
      # arguments. The first two arguments are always present and are symbols (taking
      # on the same values as field-type symbols in message descriptors) that
      # indicate the type of the map key and value fields.
      #
      # The supported key types are: :int32, :int64, :uint32, :uint64, :bool,
      # :string, :bytes.
      #
      # The supported value types are: :int32, :int64, :uint32, :uint64, :bool,
      # :string, :bytes, :enum, :message.
      #
      # The third argument, value_typeclass, must be present if value_type is :enum
      # or :message. As in RepeatedField#new, this argument must be a message class
      # (for :message) or enum module (for :enum).
      #
      # The last argument, if present, provides initial content for map. Note that
      # this may be an ordinary Ruby hashmap or another Map instance with identical
      # key and value types. Also note that this argument may be present whether or
      # not value_typeclass is present (and it is unambiguously separate from
      # value_typeclass because value_typeclass's presence is strictly determined by
      # value_type). The contents of this initial hashmap or Map instance are
      # shallow-copied into the new Map: the original map is unmodified, but
      # references to underlying objects will be shared if the value type is a
      # message type.
      def self.new(key_type, value_type, value_typeclass = nil, init_hashmap = {})
        instance = allocate
        # TODO(jatl) This argument mangling doesn't agree with the type signature,
        # but does align with the text of the comments and is required to make unit tests pass.
        if init_hashmap.empty? and ![:enum, :message].include?(value_type)
          init_hashmap = value_typeclass
          value_typeclass = nil
        end
        instance.send(:initialize, key_type, value_type, value_type_class: value_typeclass, initial_values: init_hashmap)
        instance
      end

      ##
      # call-seq:
      #     Map.keys => [list_of_keys]
      #
      # Returns the list of keys contained in the map, in unspecified order.
      def keys
        return_value = []
        internal_iterator do |iterator|
          key_message_value = Google::Protobuf::FFI.map_key(@map_ptr, iterator)
          return_value << convert_upb_to_ruby(key_message_value, key_type)
        end
        return_value
      end

      ##
      # call-seq:
      #     Map.values => [list_of_values]
      #
      # Returns the list of values contained in the map, in unspecified order.
      def values
        return_value = []
        internal_iterator do |iterator|
          value_message_value = Google::Protobuf::FFI.map_value(@map_ptr, iterator)
          return_value << convert_upb_to_ruby(value_message_value, value_type, descriptor, arena)
        end
        return_value
      end

      ##
      # call-seq:
      #    Map.[](key) => value
      #
      #  Accesses the element at the given key. Throws an exception if the key type is
      #  incorrect. Returns nil when the key is not present in the map.
      def [](key)
        value = Google::Protobuf::FFI::MessageValue.new
        key_message_value = convert_ruby_to_upb(key, arena, key_type, nil)
        if Google::Protobuf::FFI.map_get(@map_ptr, key_message_value, value)
           convert_upb_to_ruby(value, value_type, descriptor, arena)
        end
      end

      ##
      # call-seq:
      #     Map.[]=(key, value) => value
      #
      # Inserts or overwrites the value at the given key with the given new value.
      # Throws an exception if the key type is incorrect. Returns the new value that
      # was just inserted.
      def []=(key, value)
        raise FrozenError.new "can't modify frozen #{self.class}" if frozen?
        key_message_value = convert_ruby_to_upb(key, arena, key_type, nil)
        value_message_value = convert_ruby_to_upb(value, arena, value_type, descriptor)
        Google::Protobuf::FFI.map_set(@map_ptr, key_message_value, value_message_value, arena)
        value
      end

      def has_key?(key)
        key_message_value = convert_ruby_to_upb(key, arena, key_type, nil)
        Google::Protobuf::FFI.map_get(@map_ptr, key_message_value, nil)
      end

      ##
      # call-seq:
      #    Map.delete(key) => old_value
      #
      # Deletes the value at the given key, if any, returning either the old value or
      # nil if none was present. Throws an exception if the key is of the wrong type.
      def delete(key)
        raise FrozenError.new "can't modify frozen #{self.class}" if frozen?
        value = Google::Protobuf::FFI::MessageValue.new
        key_message_value = convert_ruby_to_upb(key, arena, key_type, nil)
        if Google::Protobuf::FFI.map_delete(@map_ptr, key_message_value, value)
          convert_upb_to_ruby(value, value_type, descriptor, arena)
        else
          nil
        end
      end

      def clear
        raise FrozenError.new "can't modify frozen #{self.class}" if frozen?
        Google::Protobuf::FFI.map_clear(@map_ptr)
        nil
      end

      def length
        Google::Protobuf::FFI.map_size(@map_ptr)
      end
      alias size length

      ##
      # call-seq:
      #    Map.dup => new_map
      #
      # Duplicates this map with a shallow copy. References to all non-primitive
      # element objects (e.g., submessages) are shared.
      def dup
        internal_dup
      end
      alias clone dup

      ##
      # call-seq:
      #     Map.==(other) => boolean
      #
      # Compares this map to another. Maps are equal if they have identical key sets,
      # and for each key, the values in both maps compare equal. Elements are
      # compared as per normal Ruby semantics, by calling their :== methods (or
      # performing a more efficient comparison for primitive types).
      #
      # Maps with dissimilar key types or value types/typeclasses are never equal,
      # even if value comparison (for example, between integers and floats) would
      # have otherwise indicated that every element has equal value.
      def ==(other)
        if other.is_a? Hash
          other = self.class.send(:private_constructor, key_type, value_type, descriptor, initial_values: other)
        elsif !other.is_a? Google::Protobuf::Map
          return false
        end

        return true if object_id == other.object_id
        return false if key_type != other.send(:key_type) or value_type != other.send(:value_type) or descriptor != other.send(:descriptor) or length != other.length
        other_map_ptr = other.send(:map_ptr)
        each_msg_val do |key_message_value, value_message_value|
          other_value = Google::Protobuf::FFI::MessageValue.new
          return false unless Google::Protobuf::FFI.map_get(other_map_ptr, key_message_value, other_value)
          return false unless Google::Protobuf::FFI.message_value_equal(value_message_value, other_value, value_type, descriptor)
        end
        true
      end

      def hash
        return_value = 0
        each_msg_val do |key_message_value, value_message_value|
          return_value = Google::Protobuf::FFI.message_value_hash(key_message_value, key_type, nil, return_value)
          return_value = Google::Protobuf::FFI.message_value_hash(value_message_value, value_type, descriptor, return_value)
        end
        return_value
      end

      ##
      # call-seq:
      #    Map.to_h => {}
      #
      # Returns a Ruby Hash object containing all the values within the map
      def to_h
        return {} if map_ptr.nil? or map_ptr.null?
        return_value = {}
        each_msg_val do |key_message_value, value_message_value|
          hash_key = convert_upb_to_ruby(key_message_value, key_type)
          hash_value = scalar_create_hash(value_message_value, value_type, msg_or_enum_descriptor: descriptor)
          return_value[hash_key] = hash_value
        end
        return_value
      end

      def inspect
        key_value_pairs = []
        each_msg_val do |key_message_value, value_message_value|
          key_string = convert_upb_to_ruby(key_message_value, key_type).inspect
          if value_type == :message
            sub_msg_descriptor = Google::Protobuf::FFI.get_subtype_as_message(descriptor)
            value_string = sub_msg_descriptor.msgclass.send(:inspect_internal, value_message_value[:msg_val])
          else
            value_string = convert_upb_to_ruby(value_message_value, value_type, descriptor).inspect
          end
          key_value_pairs << "#{key_string}=>#{value_string}"
        end
        "{#{key_value_pairs.join(", ")}}"
      end

      ##
      # call-seq:
      #    Map.merge(other_map) => map
      #
      # Copies key/value pairs from other_map into a copy of this map. If a key is
      # set in other_map and this map, the value from other_map overwrites the value
      # in the new copy of this map. Returns the new copy of this map with merged
      # contents.
      def merge(other)
        internal_merge(other)
      end

      ##
      # call-seq:
      #    Map.each(&block)
      #
      # Invokes &block on each |key, value| pair in the map, in unspecified order.
      # Note that Map also includes Enumerable; map thus acts like a normal Ruby
      # sequence.
      def each &block
        each_msg_val do |key_message_value, value_message_value|
          key_value = convert_upb_to_ruby(key_message_value, key_type)
          value_value = convert_upb_to_ruby(value_message_value, value_type, descriptor, arena)
          yield key_value, value_value
        end
        nil
      end

      private
      attr :arena, :map_ptr, :key_type, :value_type, :descriptor, :name

      include Google::Protobuf::Internal::Convert

      def internal_iterator
        iter = ::FFI::MemoryPointer.new(:size_t, 1)
        iter.write(:size_t, Google::Protobuf::FFI::Upb_Map_Begin)
        while Google::Protobuf::FFI.map_next(@map_ptr, iter) do
          iter_size_t = iter.read(:size_t)
          yield iter_size_t
        end
      end

      def each_msg_val &block
        internal_iterator do |iterator|
          key_message_value = Google::Protobuf::FFI.map_key(@map_ptr, iterator)
          value_message_value = Google::Protobuf::FFI.map_value(@map_ptr, iterator)
          yield key_message_value, value_message_value
        end
      end

      def internal_dup
        instance = self.class.send(:private_constructor, key_type, value_type, descriptor, arena: arena)
        new_map_ptr = instance.send(:map_ptr)
        each_msg_val do |key_message_value, value_message_value|
          Google::Protobuf::FFI.map_set(new_map_ptr, key_message_value, value_message_value, arena)
        end
        instance
      end

      def internal_merge_into_self(other)
        case other
        when Hash
          other.each do |key, value|
            key_message_value = convert_ruby_to_upb(key, arena, key_type, nil)
            value_message_value = convert_ruby_to_upb(value, arena, value_type, descriptor)
            Google::Protobuf::FFI.map_set(@map_ptr, key_message_value, value_message_value, arena)
          end
        when Google::Protobuf::Map
          unless key_type == other.send(:key_type) and value_type == other.send(:value_type) and descriptor == other.descriptor
            raise ArgumentError.new "Attempt to merge Map with mismatching types" #TODO(jatl) Improve error message by adding type information
          end
          arena.fuse(other.send(:arena))
          iter = ::FFI::MemoryPointer.new(:size_t, 1)
          iter.write(:size_t, Google::Protobuf::FFI::Upb_Map_Begin)
          other.send(:each_msg_val) do |key_message_value, value_message_value|
            Google::Protobuf::FFI.map_set(@map_ptr, key_message_value, value_message_value, arena)
          end
        else
          raise ArgumentError.new "Unknown type merging into Map" #TODO(jatl) improve this error message by including type information
        end
        self
      end

      def internal_merge(other)
        internal_dup.internal_merge_into_self(other)
      end

      def initialize(key_type, value_type, value_type_class: nil, initial_values: nil, arena: nil, map: nil, descriptor: nil, name: nil)
        @name = name || 'Map'

        unless [:int32, :int64, :uint32, :uint64, :bool, :string, :bytes].include? key_type
          raise ArgumentError.new "Invalid key type for map." #TODO(jatl) improve error message to include what type was passed
        end
        @key_type = key_type

        unless [:int32, :int64, :uint32, :uint64, :bool, :string, :bytes, :enum, :message].include? value_type
          raise ArgumentError.new "Invalid value type for map." #TODO(jatl) improve error message to include what type was passed
        end
        @value_type = value_type

        if !descriptor.nil?
          raise ArgumentError "Expected descriptor to be a Descriptor or EnumDescriptor" unless [EnumDescriptor, Descriptor].include? descriptor.class
          @descriptor = descriptor
        elsif [:message, :enum].include? value_type
          raise ArgumentError.new "Expected at least 3 arguments for message/enum." if value_type_class.nil?
          descriptor = value_type_class.respond_to?(:descriptor) ? value_type_class.descriptor : nil
          raise ArgumentError.new "Type class #{value_type_class} has no descriptor. Please pass a class or enum as returned by the DescriptorPool." if descriptor.nil?
          @descriptor = descriptor
        else
          @descriptor = nil
        end

        @arena = arena || Google::Protobuf::FFI.create_arena
        @map_ptr = map || Google::Protobuf::FFI.create_map(@arena, @key_type, @value_type)

        internal_merge_into_self(initial_values) unless initial_values.nil?

        # Should always be the last expression of the initializer to avoid
        # leaking references to this object before construction is complete.
        OBJECT_CACHE.try_add(@map_ptr.address, self)
      end

      # @param field [FieldDescriptor] Descriptor of the field where the RepeatedField will be assigned
      # @param values [Hash|Map] Initial value; may be nil or empty
      # @param arena [Arena] Owning message's arena
      def self.construct_for_field(field, arena, value: nil, map: nil)
        raise ArgumentError.new "Expected Hash object as initializer value for map field '#{field.name}' (given #{value.class})." unless value.nil? or value.is_a? Hash
        instance = allocate
        raise ArgumentError.new "Expected field with type :message, instead got #{field.class}" unless field.type == :message
        message_descriptor = field.send(:subtype)
        key_field_def = Google::Protobuf::FFI.get_field_by_number(message_descriptor, 1)
        key_field_type = Google::Protobuf::FFI.get_type(key_field_def)

        value_field_def = Google::Protobuf::FFI.get_field_by_number(message_descriptor, 2)
        value_field_type = Google::Protobuf::FFI.get_type(value_field_def)
        instance.send(:initialize, key_field_type, value_field_type, initial_values: value, name: field.name, arena: arena, map: map, descriptor: value_field_def.subtype)
        instance
      end

      def self.private_constructor(key_type, value_type, descriptor, initial_values: nil, arena: nil)
        instance = allocate
        instance.send(:initialize, key_type, value_type, descriptor: descriptor, initial_values: initial_values, arena: arena)
        instance
      end

      extend Google::Protobuf::Internal::Convert

      def self.deep_copy(map)
        instance = allocate
        instance.send(:initialize, map.send(:key_type), map.send(:value_type), descriptor: map.send(:descriptor))
        map.send(:each_msg_val) do |key_message_value, value_message_value|
          Google::Protobuf::FFI.map_set(instance.send(:map_ptr), key_message_value, message_value_deep_copy(value_message_value, map.send(:value_type), map.send(:descriptor), instance.send(:arena)), instance.send(:arena))
        end
        instance
      end
    end
  end
end
