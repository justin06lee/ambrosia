#pragma once

#include <string>
#include <string_view>

// Finder's order for names: case-insensitive, numbers by value (file2 before
// file10), punctuation before digits before letters. A key compares with
// memcmp, so a folder of 100k names sorts as a plain byte sort.
namespace SortKey {

// Appends the key for an ASCII name to out and returns true. A name that isn't
// plain ASCII appends nothing and returns false: such folders sort with ICU
// (QCollator) instead, which this order agrees with on ASCII.
bool append(std::string_view name, std::string &out);

}
