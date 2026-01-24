// Copyright © 2026 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#include "log_writer_factory.h"
#include "composite_log_writer.h"
#include "html_log_writer.h"
#include "markdown_log_writer.h"
#include "csv_log_writer.h"
#include "yaml_log_writer.h"
#include "log_writer.h"

std::unique_ptr<ILogWriter> LogWriterFactory::create(const Options& opt) {
  auto composite = std::make_unique<CompositeLogWriter>();
  
  // Standard Writer (Stdout/File)
  composite->add(std::make_unique<LogWriter>(opt));

  if (!opt.htmlReport.empty()) {
    composite->add(std::make_unique<HtmlLogWriter>(opt.htmlReport));
  }
  if (!opt.markdownReport.empty()) {
    composite->add(std::make_unique<MarkdownLogWriter>(opt.markdownReport));
  }
  if (!opt.csvOutput.empty()) {
    composite->add(std::make_unique<CsvLogWriter>(opt.csvOutput));
  }
  if (!opt.yamlOutput.empty()) {
    composite->add(std::make_unique<YamlLogWriter>(opt.yamlOutput));
  }
  
  return composite;
}
