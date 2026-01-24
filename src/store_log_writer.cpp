// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "store_log_writer.h"

void StoreLogWriter::writeEntry(const LogEntry& entry) {
    if (capacity_ > 0 && entries_.size() >= capacity_) {
        return;
    }
    entries_.push_back(entry);
}

void StoreLogWriter::writeRaw(const std::string& /*unused*/) {
    // Ignore raw content for storage
}

void StoreLogWriter::clear() {
    entries_.clear();
}

void StoreLogWriter::setCapacity(size_t maxEntries) {
    capacity_ = maxEntries;
}

bool StoreLogWriter::isFull() const {
    return capacity_ > 0 && entries_.size() >= capacity_;
}


void StoreLogWriter::writeStats(const LogStats& /*unused*/) {
    // Ignore stats
}

void StoreLogWriter::writeDiffSummary(const DiffEngine::DiffStats& /*stats*/) {
    // No-op
}

void StoreLogWriter::setUseColor(bool /*unused*/) {
    // No-op
}

void StoreLogWriter::writeStatsJson(const LogStats& /*unused*/, const std::string& /*unused*/) const {
    // No-op
}


void StoreLogWriter::flush() {
    // No-op
}

const std::vector<LogEntry>& StoreLogWriter::getEntries() const {
    return entries_;
}
