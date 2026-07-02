// valhalla_jni.cpp
//
// Thin JNI adapter: converts between JNI types and the plain C API
// in valhalla_capi.h. All logic lives in valhalla_capi.cpp.

#include <jni.h>
#include <android/log.h>
#include "valhalla_capi.h"

#define LOG_TAG "ValhallaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static ValhallActor* g_actor = nullptr;

// Convert a C API result to a jstring and free the original.
static jstring to_jstring_and_free(JNIEnv* env, char* str) {
    jstring result = env->NewStringUTF(str);
    valhalla_free_string(str);
    return result;
}

extern "C" {

JNIEXPORT void JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeInit(
        JNIEnv* env, jobject /* thiz */, jstring jConfigPath) {
    const char* path = env->GetStringUTFChars(jConfigPath, nullptr);
    char* error = nullptr;
    g_actor = valhalla_create(path, &error);
    if (g_actor) {
        LOGI("actor initialised from %s", path);
    } else {
        LOGE("nativeInit failed: %s", error ? error : "unknown");
        valhalla_free_string(error);
    }
    env->ReleaseStringUTFChars(jConfigPath, path);
}

JNIEXPORT void JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeDestroy(
        JNIEnv* /* env */, jobject /* thiz */) {
    valhalla_destroy(g_actor);
    g_actor = nullptr;
    LOGI("actor destroyed");
}

JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeRoute(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    const char* req = env->GetStringUTFChars(jRequest, nullptr);
    char* result = valhalla_route(g_actor, req);
    env->ReleaseStringUTFChars(jRequest, req);
    return to_jstring_and_free(env, result);
}

JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeOptimizedRoute(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    const char* req = env->GetStringUTFChars(jRequest, nullptr);
    char* result = valhalla_optimized_route(g_actor, req);
    env->ReleaseStringUTFChars(jRequest, req);
    return to_jstring_and_free(env, result);
}

JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeTraceRoute(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    const char* req = env->GetStringUTFChars(jRequest, nullptr);
    char* result = valhalla_trace_route(g_actor, req);
    env->ReleaseStringUTFChars(jRequest, req);
    return to_jstring_and_free(env, result);
}

JNIEXPORT jstring JNICALL
Java_ch_vautherin_valhalla_kmp_ValhallaEngine_nativeTraceAttributes(
        JNIEnv* env, jobject /* thiz */, jstring jRequest) {
    const char* req = env->GetStringUTFChars(jRequest, nullptr);
    char* result = valhalla_trace_attributes(g_actor, req);
    env->ReleaseStringUTFChars(jRequest, req);
    return to_jstring_and_free(env, result);
}

} // extern "C"
