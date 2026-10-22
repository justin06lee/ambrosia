#pragma once

#include <QString>

// How Finder writes sizes, dates and kinds in its views.
namespace Format {

// "612 bytes", "84 KB", "1.8 MB": decimal units, as Finder counts them.
QString size(qint64 bytes);
// "Today at 11:05 AM", "Yesterday at 5:52 PM", "Oct 3, 2026 at 9:30 AM";
// shorter for a narrow column, as Finder does: level 1 "Yesterday, 5:52 PM",
// "10/3/26, 9:30 AM"; level 2 "Yesterday", "10/3/26", and today just the time.
QString date(qint64 secsSinceEpoch, int level = 0);
// Get Info's dates: "Monday, October 19, 2026 at 9:12 AM".
QString longDate(qint64 secsSinceEpoch);
// Quick Look's: "Sep 28, 2026 at 8:47:00 AM".
QString secondsDate(qint64 secsSinceEpoch);
// Get Info's exact sizes: "524,288 bytes", "422 bytes", "Zero bytes".
QString bytes(qint64 bytes);
// "Folder", "PDF Document", "Plain Text", ... from the name's extension.
QString kind(const QString &name, bool dir);
// What Finder writes for a kind when its column is too narrow: "Text",
// "PDF", "ZIP"; the kind itself when it has no shorter name.
QString shortKind(const QString &kind);
// Which of our icons draws it: "folder" or "document".
QString icon(const QString &name, bool dir);
// The badge a document icon carries: the extension, upper-cased ("PDF").
QString badge(const QString &name, bool dir);

}
