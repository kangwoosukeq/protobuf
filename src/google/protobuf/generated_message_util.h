// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Author: kenton@google.com (Kenton Varda)
//  Based on original Protocol Buffers design by
//  Sanjay Ghemawat, Jeff Dean, and others.
//
// This file contains miscellaneous helper code used by generated code --
// including lite types -- but which should not be used directly by users.

#ifndef GOOGLE_PROTOBUF_GENERATED_MESSAGE_UTIL_H__
#define GOOGLE_PROTOBUF_GENERATED_MESSAGE_UTIL_H__

#include <assert.h>

#include <algorithm>
#include <atomic>
#include <climits>
#include <cstddef>
#include <memory>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

#include "google/protobuf/stubs/common.h"
#include "absl/base/call_once.h"
#include "absl/base/casts.h"
#include "absl/strings/string_view.h"
#include "google/protobuf/any.h"
#include "google/protobuf/has_bits.h"
#include "google/protobuf/implicit_weak_message.h"
#include "google/protobuf/message_lite.h"
#include "google/protobuf/port.h"
#include "google/protobuf/repeated_field.h"
#include "google/protobuf/wire_format_lite.h"


// Must be included last.
#include "google/protobuf/port_def.inc"

#ifdef SWIG
#error "You cannot SWIG proto headers"
#endif

namespace google {
namespace protobuf {

class Arena;
class Message;

namespace io {
class CodedInputStream;
}

namespace internal {


// This fastpath inlines a single branch instead of having to make the
// InitProtobufDefaults function call.
// It also generates less inlined code than a function-scope static initializer.
PROTOBUF_EXPORT extern std::atomic<bool> init_protobuf_defaults_state;
PROTOBUF_EXPORT void InitProtobufDefaultsSlow();
PROTOBUF_EXPORT inline void InitProtobufDefaults() {
  if (PROTOBUF_PREDICT_FALSE(
          !init_protobuf_defaults_state.load(std::memory_order_acquire))) {
    InitProtobufDefaultsSlow();
  }
}

// This used by proto1
PROTOBUF_EXPORT inline const std::string& GetEmptyString() {
  InitProtobufDefaults();
  return GetEmptyStringAlreadyInited();
}

// Default empty Cord object. Don't use directly. Instead, call
// GetEmptyCordAlreadyInited() to get the reference.
union EmptyCord {
  constexpr EmptyCord() : value() {}
  ~EmptyCord() {}
  ::absl::Cord value;
};
PROTOBUF_EXPORT extern const EmptyCord empty_cord_;

constexpr const ::absl::Cord& GetEmptyCordAlreadyInited() {
  return empty_cord_.value;
}

// True if IsInitialized() is true for all elements of t.  Type is expected
// to be a RepeatedPtrField<some message type>.  It's useful to have this
// helper here to keep the protobuf compiler from ever having to emit loops in
// IsInitialized() methods.  We want the C++ compiler to inline this or not
// as it sees fit.
template <typename Msg>
bool AllAreInitialized(const RepeatedPtrField<Msg>& t) {
  for (int i = t.size(); --i >= 0;) {
    if (!t.Get(i).IsInitialized()) return false;
  }
  return true;
}

// "Weak" variant of AllAreInitialized, used to implement implicit weak fields.
// This version operates on MessageLite to avoid introducing a dependency on the
// concrete message type.
template <class T>
bool AllAreInitializedWeak(const RepeatedPtrField<T>& t) {
  for (int i = t.size(); --i >= 0;) {
    if (!reinterpret_cast<const RepeatedPtrFieldBase&>(t)
             .Get<ImplicitWeakTypeHandler<T> >(i)
             .IsInitialized()) {
      return false;
    }
  }
  return true;
}

inline bool IsPresent(const void* base, uint32_t hasbit) {
  const uint32_t* has_bits_array = static_cast<const uint32_t*>(base);
  return (has_bits_array[hasbit / 32] & (1u << (hasbit & 31))) != 0;
}

inline bool IsOneofPresent(const void* base, uint32_t offset, uint32_t tag) {
  const uint32_t* oneof = reinterpret_cast<const uint32_t*>(
      static_cast<const uint8_t*>(base) + offset);
  return *oneof == tag >> 3;
}

typedef void (*SpecialSerializer)(const uint8_t* base, uint32_t offset,
                                  uint32_t tag, uint32_t has_offset,
                                  io::CodedOutputStream* output);

PROTOBUF_EXPORT void ExtensionSerializer(const MessageLite* extendee,
                                         const uint8_t* ptr, uint32_t offset,
                                         uint32_t tag, uint32_t has_offset,
                                         io::CodedOutputStream* output);
PROTOBUF_EXPORT void UnknownFieldSerializerLite(const uint8_t* base,
                                                uint32_t offset, uint32_t tag,
                                                uint32_t has_offset,
                                                io::CodedOutputStream* output);

PROTOBUF_EXPORT MessageLite* DuplicateIfNonNullInternal(MessageLite* message);
PROTOBUF_EXPORT MessageLite* GetOwnedMessageInternal(Arena* message_arena,
                                                     MessageLite* submessage,
                                                     Arena* submessage_arena);
PROTOBUF_EXPORT void GenericSwap(MessageLite* m1, MessageLite* m2);
// We specialize GenericSwap for non-lite messages to benefit from reflection.
PROTOBUF_EXPORT void GenericSwap(Message* m1, Message* m2);

template <typename T>
T* DuplicateIfNonNull(T* message) {
  // The casts must be reinterpret_cast<> because T might be a forward-declared
  // type that the compiler doesn't know is related to MessageLite.
  return reinterpret_cast<T*>(
      DuplicateIfNonNullInternal(reinterpret_cast<MessageLite*>(message)));
}

template <typename T>
T* GetOwnedMessage(Arena* message_arena, T* submessage,
                   Arena* submessage_arena) {
  // The casts must be reinterpret_cast<> because T might be a forward-declared
  // type that the compiler doesn't know is related to MessageLite.
  return reinterpret_cast<T*>(GetOwnedMessageInternal(
      message_arena, reinterpret_cast<MessageLite*>(submessage),
      submessage_arena));
}

// Hide atomic from the public header and allow easy change to regular int
// on platforms where the atomic might have a perf impact.
//
// CachedSize is like std::atomic<int> but with some important changes:
//
// 1) CachedSize uses Get / Set rather than load / store.
// 2) CachedSize always uses relaxed ordering.
// 3) CachedSize is assignable and copy-constructible.
// 4) CachedSize has a constexpr default constructor, and a constexpr
//    constructor that takes an int argument.
// 5) If the compiler supports the __atomic_load_n / __atomic_store_n builtins,
//    then CachedSize is trivially copyable.
//
// Developed at https://godbolt.org/z/vYcx7zYs1 ; supports gcc, clang, MSVC.
class PROTOBUF_EXPORT CachedSize {
 private:
  using Scalar = int;

 public:
  constexpr CachedSize() noexcept : atom_(Scalar{}) {}
  // NOLINTNEXTLINE(google-explicit-constructor)
  constexpr CachedSize(Scalar desired) noexcept : atom_(desired) {}
#if PROTOBUF_BUILTIN_ATOMIC
  constexpr CachedSize(const CachedSize& other) = default;

  Scalar Get() const noexcept {
    return __atomic_load_n(&atom_, __ATOMIC_RELAXED);
  }

  void Set(Scalar desired) noexcept {
    __atomic_store_n(&atom_, desired, __ATOMIC_RELAXED);
  }
#else
  CachedSize(const CachedSize& other) noexcept : atom_(other.Get()) {}
  CachedSize& operator=(const CachedSize& other) noexcept {
    Set(other.Get());
    return *this;
  }

  Scalar Get() const noexcept {  //
    return atom_.load(std::memory_order_relaxed);
  }

  void Set(Scalar desired) noexcept {
    atom_.store(desired, std::memory_order_relaxed);
  }
#endif

 private:
#if PROTOBUF_BUILTIN_ATOMIC
  Scalar atom_;
#else
  std::atomic<Scalar> atom_;
#endif
};

PROTOBUF_EXPORT void DestroyMessage(const void* message);
PROTOBUF_EXPORT void DestroyString(const void* s);
// Destroy (not delete) the message
inline void OnShutdownDestroyMessage(const void* ptr) {
  OnShutdownRun(DestroyMessage, ptr);
}
// Destroy the string (call std::string destructor)
inline void OnShutdownDestroyString(const std::string* ptr) {
  OnShutdownRun(DestroyString, ptr);
}

// Helpers for deterministic serialization =============================

// Iterator base for MapSorterFlat and MapSorterPtr.
template <typename storage_type>
struct MapSorterIt {
  storage_type* ptr;
  MapSorterIt(storage_type* ptr) : ptr(ptr) {}
  bool operator==(const MapSorterIt& other) const { return ptr == other.ptr; }
  bool operator!=(const MapSorterIt& other) const { return !(*this == other); }
  MapSorterIt& operator++() {
    ++ptr;
    return *this;
  }
  MapSorterIt operator++(int) {
    auto other = *this;
    ++ptr;
    return other;
  }
  MapSorterIt operator+(int v) { return MapSorterIt{ptr + v}; }
};

// Defined outside of MapSorterFlat to only be templatized on the key.
template <typename KeyT>
struct MapSorterLessThan {
  using storage_type = std::pair<KeyT, const void*>;
  bool operator()(const storage_type& a, const storage_type& b) const {
    return a.first < b.first;
  }
};

// MapSorterFlat stores keys inline with pointers to map entries, so that
// keys can be compared without indirection. This type is used for maps with
// keys that are not strings.
template <typename MapT>
class MapSorterFlat {
 public:
  using value_type = typename MapT::value_type;
  // To avoid code bloat we don't put `value_type` in `storage_type`. It is not
  // necessary for the call to sort, and avoiding it prevents unnecessary
  // separate instantiations of sort.
  using storage_type = std::pair<typename MapT::key_type, const void*>;

  // This const_iterator dereferenes to the map entry stored in the sorting
  // array pairs. This is the same interface as the Map::const_iterator type,
  // and allows generated code to use the same loop body with either form:
  //   for (const auto& entry : map) { ... }
  //   for (const auto& entry : MapSorterFlat(map)) { ... }
  struct const_iterator : public MapSorterIt<storage_type> {
    using pointer = const typename MapT::value_type*;
    using reference = const typename MapT::value_type&;
    using MapSorterIt<storage_type>::MapSorterIt;

    pointer operator->() const {
      return static_cast<const value_type*>(this->ptr->second);
    }
    reference operator*() const { return *this->operator->(); }
  };

  explicit MapSorterFlat(const MapT& m)
      : size_(m.size()), items_(size_ ? new storage_type[size_] : nullptr) {
    if (!size_) return;
    storage_type* it = &items_[0];
    for (const auto& entry : m) {
      *it++ = {entry.first, &entry};
    }
    std::sort(&items_[0], &items_[size_],
              MapSorterLessThan<typename MapT::key_type>{});
  }
  size_t size() const { return size_; }
  const_iterator begin() const { return {items_.get()}; }
  const_iterator end() const { return {items_.get() + size_}; }

 private:
  size_t size_;
  std::unique_ptr<storage_type[]> items_;
};

// Defined outside of MapSorterPtr to only be templatized on the key.
template <typename KeyT>
struct MapSorterPtrLessThan {
  bool operator()(const void* a, const void* b) const {
    // The pointers point to the `std::pair<const Key, Value>` object.
    // We cast directly to the key to read it.
    return *reinterpret_cast<const KeyT*>(a) <
           *reinterpret_cast<const KeyT*>(b);
  }
};

// MapSorterPtr stores and sorts pointers to map entries. This type is used for
// maps with keys that are strings.
template <typename MapT>
class MapSorterPtr {
 public:
  using value_type = typename MapT::value_type;
  // To avoid code bloat we don't put `value_type` in `storage_type`. It is not
  // necessary for the call to sort, and avoiding it prevents unnecessary
  // separate instantiations of sort.
  using storage_type = const void*;

  // This const_iterator dereferenes the map entry pointer stored in the sorting
  // array. This is the same interface as the Map::const_iterator type, and
  // allows generated code to use the same loop body with either form:
  //   for (const auto& entry : map) { ... }
  //   for (const auto& entry : MapSorterPtr(map)) { ... }
  struct const_iterator : public MapSorterIt<storage_type> {
    using pointer = const typename MapT::value_type*;
    using reference = const typename MapT::value_type&;
    using MapSorterIt<storage_type>::MapSorterIt;

    pointer operator->() const {
      return static_cast<const value_type*>(*this->ptr);
    }
    reference operator*() const { return *this->operator->(); }
  };

  explicit MapSorterPtr(const MapT& m)
      : size_(m.size()), items_(size_ ? new storage_type[size_] : nullptr) {
    if (!size_) return;
    storage_type* it = &items_[0];
    for (const auto& entry : m) {
      *it++ = &entry;
    }
    static_assert(PROTOBUF_FIELD_OFFSET(typename MapT::value_type, first) == 0,
                  "Must hold for MapSorterPtrLessThan to work.");
    std::sort(&items_[0], &items_[size_],
              MapSorterPtrLessThan<typename MapT::key_type>{});
  }
  size_t size() const { return size_; }
  const_iterator begin() const { return {items_.get()}; }
  const_iterator end() const { return {items_.get() + size_}; }

 private:
  size_t size_;
  std::unique_ptr<storage_type[]> items_;
};

}  // namespace internal
}  // namespace protobuf
}  // namespace google

#include "google/protobuf/port_undef.inc"

#endif  // GOOGLE_PROTOBUF_GENERATED_MESSAGE_UTIL_H__
