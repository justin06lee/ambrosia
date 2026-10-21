#include "sortkey.h"

#include <QCollator>

#include <algorithm>
#include <array>
#include <cstdint>

namespace {

constexpr char Digits = 0x40; // after every punctuation rank, before 'a'

bool isDigit(unsigned char c) { return c >= '0' && c <= '9'; }
bool isUpper(unsigned char c) { return c >= 'A' && c <= 'Z'; }
bool isLower(unsigned char c) { return c >= 'a' && c <= 'z'; }

// Each ASCII space and punctuation character's place in ICU's order, from
// 0x02 up, so this order agrees with the ICU one non-ASCII folders use.
const std::array<uint8_t, 128> &punctuationRank()
{
    static const std::array<uint8_t, 128> table = [] {
        std::array<uint8_t, 128> rank{};
        QString chars;
        for (int c = 0x20; c < 0x7f; ++c)
            if (!isDigit(c) && !isUpper(c) && !isLower(c))
                chars.append(QChar(c));
        QCollator collator;
        collator.setNumericMode(true);
        collator.setCaseSensitivity(Qt::CaseInsensitive);
        std::stable_sort(chars.begin(), chars.end(), [&](QChar a, QChar b) {
            return collator.compare(QString(a), QString(b)) < 0;
        });
        for (int i = 0; i < chars.size(); ++i)
            rank[chars[i].unicode()] = uint8_t(0x02 + i);
        return rank;
    }();
    return table;
}

}

bool SortKey::append(std::string_view name, std::string &out)
{
    for (unsigned char c : name)
        if (c < 0x20 || c >= 0x7f)
            return false;
    const auto &rank = punctuationRank();
    // What the primary key ignores, compared only between equal keys: each
    // letter's case (lowercase first, as ICU) and each number's leading zeros.
    std::string tail;
    for (size_t i = 0; i < name.size();) {
        const unsigned char c = name[i];
        if (isDigit(c)) {
            size_t start = i;
            while (start < name.size() && name[start] == '0')
                ++start;
            size_t end = start;
            while (end < name.size() && isDigit(name[end]))
                ++end;
            if (start == end) // all zeros: the number is 0
                --start;
            out.push_back(Digits);
            out.push_back(char(std::min<size_t>(end - start, 255)));
            out.append(name.substr(start, end - start));
            tail.push_back(char(1 + std::min<size_t>(start - i, 200)));
            i = end;
        } else if (isUpper(c) || isLower(c)) {
            out.push_back(char(isUpper(c) ? c + ('a' - 'A') : c));
            tail.push_back(isUpper(c) ? 2 : 1);
            ++i;
        } else {
            out.push_back(char(rank[c]));
            ++i;
        }
    }
    out.push_back('\0');
    out.append(tail);
    out.push_back('\0');
    out.append(name);
    return true;
}
