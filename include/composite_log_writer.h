// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include <vector>
#include <memory>

class CompositeLogWriter : public ILogWriter {
public:
    void add(std::unique_ptr<ILogWriter> writer) {
        if (writer) {
            writers_.push_back(std::move(writer));
        }
    }

    void writeEntry(const LogEntry& entry) override {
        for (auto& w : writers_) w->writeEntry(entry);
    }

    void writeRaw(const std::string& content) override {
        for (auto& w : writers_) w->writeRaw(content);
    }

    void writeStats(const LogStats& stats) override {
        for (auto& w : writers_) w->writeStats(stats);
    }

    void setUseColor(bool enable) override {
        for (auto& w : writers_) w->setUseColor(enable);
    }

    void writeStatsJson(const LogStats& stats, const std::string& path) const override {
        for (auto& w : writers_) w->writeStatsJson(stats, path);
    }

    void flush() override {
        for (auto& w : writers_) w->flush();
    }

private:
    std::vector<std::unique_ptr<ILogWriter>> writers_;
};
