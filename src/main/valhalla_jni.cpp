// valhalla_jni.cpp
//
// JNI glue between Kotlin ValhallaEngine and libvalhalla.so.
//
// Lifecycle:
//   nativeInit(configPath)  — parse config JSON, create a singleton actor_t.
//                             Call once at app start (expensive: loads graph reader).
//   nativeRoute(request)    — use the singleton actor for routing (cheap).
//   nativeDestroy()         — tear down the actor on app exit / reconfiguration.
//
// Thread safety: all calls are serialised with g_mutex. Valhalla's actor_t is not
// documented as thread-safe, so we take the safe path.

#include <jni.h>
#include <string>
#include <mutex>
#include <memory>
#include <android/log.h>

#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/json_parser.hpp>
#include <valhalla/tyr/actor.h>
#include <valhalla/worker.h>

#define LOG_TAG "ValhallaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static std::mutex                              g_mutex;
static std::unique_ptr<valhalla::tyr::actor_t> g_actor;

// Convert a jstring to std::string and release the JNI chars immediately.
static std::string to_std_string(JNIEnv* env, jstring js) {
    const char* chars = env->GetStringUTFChars(js, nullptr);
    std::string s(chars);
    env->ReleaseStringUTFChars(js, chars);
    return s;
}

// Invoke fn(actor) under the mutex, catching all Valhalla / std exceptions.
// On error returns a JSON object: {"code": N, "message": "..."}.
template<typename Fn>
static jstring call_actor(JNIEnv* env, Fn fn) {
    std::string result;
    try {
        std::lock_guard<std::mutex> lock(g_mutex);
        if (!g_actor) {
            return env->NewStringUTF(
                "{\"code\":-1,\"message\":\"ValhallaEngine not initialised — call nativeInit first\"}");
        }
        result = fn(*g_actor);
    } catch (const valhalla::valhalla_exception_t& e) {
        LOGE("valhalla_exception [%u]: %s", e.code, e.message.c_str());
        result = "{\"code\":" + std::to_string(e.code) +
                 ",\"message\":\"" + e.message + "\"}";
    } catch (const std::exception& e) {
        LOGE("std::exception: %s", e.what());
        result = std::string("{\"code\":-1,\"message\":\"") + e.what() + "\"}";
    } catch (...) {
        LOGE("unknown exception");
        result = "{\"code\":-1,\"message\":\"unknown exception\"}";
    }
    return env->NewStringUTF(result.c_str());
}

extern "C" {

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// ValhallaEngine.nativeInit(configPath: String)
//
// Parses the Valhalla config JSON at configPath and constructs the actor.
// auto_cleanup=false keeps workers alive between calls (no re-init overhead).
JNIEXPORT void JNICALL
Java_ch_vautherin_valhalla_1android_ValhallaEngine_nativeInit(
        JNIEnv* env, jobject /* thiz */, jstring jConfigPath) {
    std::string config_path = to_std_string(env, jConfigPath);
    try {
        boost::property_tree::ptree pt;
        boost::property_tree::json_parser::read_json(config_path, pt);
        std::lock_guard<std::mutex> lock(g_mutex);
        g_actor = std::make_unique<valhalla::tyr::actor_t>(pt, /*auto_cleanup=*/false);
        LOGI("actor initialised from %s", config_path.c_str());
    } catch (const std::exception& e) {
        LOGE("nativeInit failed: %s", e.what());
    }
}

// ValhallaEngine.nativeDestroy()
//
// Destroys the singleton actor. Call when the engine is no longer needed,
// or before re-initialising with a different config.
JNIEXPORT void JNICALL
Java_ch_vautherin_valhalla_1android_ValhallaEngine_nativeDestroy(
        JNIEnv* /* env */, jobject /* thiz */) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_actor.reset();
    LOGI("actor destroyed");
}

// ---------------------------------------------------------------------------
// Routing actions — all accept a raw Valhalla JSON request string,
// return a raw Valhalla JSON response string (or a JSON error object).
// ---------------------------------------------------------------------------

// ValhallaEngine.nativeRoute(requestJson: String): String
JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_1android_ValhallaEngine_nativeRoute(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    std::string req = to_std_string(env, jRequest);
    return call_actor(env, [&](valhalla::tyr::actor_t& actor) {
        return actor.route(req);
    });
}

// ValhallaEngine.nativeTraceRoute(requestJson: String): String
JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_1android_ValhallaEngine_nativeTraceRoute(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    std::string req = to_std_string(env, jRequest);
    return call_actor(env, [&](valhalla::tyr::actor_t& actor) {
        return actor.trace_route(req);
    });
}

// ValhallaEngine.nativeTraceAttributes(requestJson: String): String
JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_1android_ValhallaEngine_nativeTraceAttributes(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    std::string req = to_std_string(env, jRequest);
    return call_actor(env, [&](valhalla::tyr::actor_t& actor) {
        return actor.trace_attributes(req);
    });
}

} // extern "C"
