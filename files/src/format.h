#pragma once

#include <QString>

// How Finder writes sizes, dates and kinds in its views.
namespace Format {

// "612 bytes", "84 KB", "1.8 MB": decimal units, as Finder counts them.
QString size(qint64 bytes);
// "Today at 11:05 AM", "Yesterday at 5:52 PM", "Oct 3, 2026 at 9:30 AM".
QString date(qint64 secsSinceEpoch);
// "Folder", "PDF Document", "Plain Text", ... from the name's extension.
QString kind(const QString &name, bool dir);
// Which of our icons draws it: "folder" or "document".
QString icon(const QString &name, bool dir);
// The badge a document icon carries: the extension, upper-cased ("PDF").
QString badge(const QString &name, bool dir);

}
