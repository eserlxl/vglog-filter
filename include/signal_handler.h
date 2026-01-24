#pragma once

namespace signalHandler {

/**
 * @brief Installs signal handlers for SIGINT and SIGTERM.
 *
 * Sets an internal atomic flag when triggered.
 */
void install();

/**
 * @brief Checks if a stop signal has been received.
 * @return true if SIGINT/SIGTERM was caught.
 */
[[nodiscard]] bool isStopRequested();

} // namespace signalHandler
