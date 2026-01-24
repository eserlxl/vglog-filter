// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "store_log_writer.h"

void StoreLogWriter::writeEntry(const LogEntry& entry) {
    entries_.push_back(entry);
}

void StoreLogWriter::writeRaw(const std::string&) {
    // Ignore raw content for storage
}

void StoreLogWriter::writeStats(const LogStats&) {
    // Ignore stats
}

void StoreLogWriter::setUseColor(bool) {
    // No-op
}

void StoreLogWriter::writeStatsJson(const LogStats&, const std::string&) const {
    // No-op
}

void StoreLogWriter::flush() {
    // No-op
}

const std::vector<LogEntry>& StoreLogWriter::getEntries() const {
    return entries_;
}
