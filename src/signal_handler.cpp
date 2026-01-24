#include "signal_handler.h"
#include <atomic>
#include <csignal>

namespace signalHandler {

namespace {
std::atomic_bool g_stop_requested{false};

void handle_signal(int signal) {
  if (signal == SIGINT || signal == SIGTERM) {
    g_stop_requested.store(true, std::memory_order_relaxed);
  }
}
} // namespace

void install() {
  struct sigaction sa{};
  sa.sa_handler = handle_signal;
  sigemptyset(&sa.sa_mask);
  // Do not set SA_RESTART: we want blocking IO to return EINTR
  sa.sa_flags = 0;

  sigaction(SIGINT, &sa, nullptr);
  sigaction(SIGTERM, &sa, nullptr);
}

bool isStopRequested() {
  return g_stop_requested.load(std::memory_order_relaxed);
}

} // namespace signalHandler
