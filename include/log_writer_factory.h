// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "ilog_writer.h"
#include "options.h"
#include <memory>

class LogWriterFactory {
public:
  [[nodiscard]] static std::unique_ptr<ILogWriter> create(const Options& opt);
};
