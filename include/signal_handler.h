#pragma once

namespace signal_handler {

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
bool is_stop_requested();

} // namespace signal_handler
