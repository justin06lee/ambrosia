#pragma once

#include <QString>
#include <QStringList>

#include <atomic>
#include <functional>
#include <string>
#include <vector>

// Search's Contents: the files under some folders whose text has the words,
// as rg finds them (hidden items, binaries and files over 8 MB left out),
// but read with O_NOATIME, so looking through a file doesn't make it
// "opened": rg's reads set every file's access time, which is Date Last
// Opened. Letters are matched without case (ASCII; other characters as
// typed). Runs on the calling thread at idle I/O priority, until stop is
// set, limitMs pass or maxHits are found; found() gets the paths in
// batches as they come.
namespace Contents {

void search(const QString &text, const QStringList &dirs, const std::atomic<bool> &stop, int limitMs, size_t maxHits,
            const std::function<void(std::vector<std::string> &&)> &found);

}
