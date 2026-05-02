// valhalla_capi.cpp
//
// C API implementation wrapping Valhalla's actor_t.
// Each ValhallActor owns its own mutex, so concurrent calls on the same
// handle are serialised (actor_t is not thread-safe).

#include "valhalla_capi.h"

#include <cstdlib>
#include <cstring>
#include <mutex>
#include <memory>
#include <string>

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <valhalla/tyr/actor.h>
#include <valhalla/worker.h>

struct ValhallActor {
    std::mutex mutex;
    std::unique_ptr<valhalla::tyr::actor_t> actor;
};

// Duplicate a std::string as a malloc'd C string.
static char* to_c_string(const std::string& s) {
    char* c = static_cast<char*>(std::malloc(s.size() + 1));
    if (c) std::memcpy(c, s.c_str(), s.size() + 1);
    return c;
}

// Invoke fn(actor) under the handle's mutex, catching all exceptions.
// Returns a malloc'd string: either the successful result or a JSON error.
template<typename Fn>
static char* call_actor(ValhallActor* actor, Fn fn) {
    if (!actor) {
        return to_c_string(
            "{\"code\":-1,\"message\":\"actor not initialised — call valhalla_create first\"}");
    }
    std::string result;
    try {
        std::lock_guard<std::mutex> lock(actor->mutex);
        result = fn(*actor->actor);
    } catch (const valhalla::valhalla_exception_t& e) {
        result = "{\"code\":" + std::to_string(e.code) +
                 ",\"message\":\"" + e.message + "\"}";
    } catch (const std::exception& e) {
        result = std::string("{\"code\":-1,\"message\":\"") + e.what() + "\"}";
    } catch (...) {
        result = "{\"code\":-1,\"message\":\"unknown exception\"}";
    }
    return to_c_string(result);
}

extern "C" {

ValhallActor* valhalla_create(const char* config_path, char** error_out) {
    try {
        boost::property_tree::ptree pt;
        boost::property_tree::json_parser::read_json(config_path, pt);
        auto* handle = new ValhallActor();
        handle->actor = std::make_unique<valhalla::tyr::actor_t>(pt, /*auto_cleanup=*/false);
        return handle;
    } catch (const std::exception& e) {
        if (error_out) *error_out = to_c_string(e.what());
        return nullptr;
    }
}

void valhalla_destroy(ValhallActor* actor) {
    delete actor;
}

char* valhalla_route(ValhallActor* actor, const char* request_json) {
    return call_actor(actor, [&](valhalla::tyr::actor_t& a) {
        return a.route(std::string(request_json));
    });
}

char* valhalla_trace_route(ValhallActor* actor, const char* request_json) {
    return call_actor(actor, [&](valhalla::tyr::actor_t& a) {
        return a.trace_route(std::string(request_json));
    });
}

char* valhalla_trace_attributes(ValhallActor* actor, const char* request_json) {
    return call_actor(actor, [&](valhalla::tyr::actor_t& a) {
        return a.trace_attributes(std::string(request_json));
    });
}

void valhalla_free_string(char* str) {
    std::free(str);
}

} // extern "C"
