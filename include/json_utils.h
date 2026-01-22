#pragma once

#include <string>
#include <string_view>

namespace json_utils {

[[nodiscard]] std::string escape_string(std::string_view s);

} // namespace json_utils
