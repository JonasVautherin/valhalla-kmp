// valhalla_capi.h
//
// Plain C interface to the Valhalla routing engine.
// Used by JNI on Android and by cinterop on iOS.

#ifndef VALHALLA_CAPI_H
#define VALHALLA_CAPI_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ValhallActor ValhallActor;

// Create an actor from a Valhalla config JSON file.
// Returns NULL on failure; if error_out is non-NULL, sets it to an error
// message (caller must free with valhalla_free_string).
ValhallActor* valhalla_create(const char* config_path, char** error_out);

// Destroy an actor. Safe to call with NULL.
void valhalla_destroy(ValhallActor* actor);

// Routing actions — all accept a raw Valhalla JSON request string and return
// a malloc'd JSON response string (or a JSON error object).
// The caller must free the returned string with valhalla_free_string.
// If actor is NULL, returns a JSON error.
char* valhalla_route(ValhallActor* actor, const char* request_json);
// Reorders the intermediate locations (first and last held fixed) to minimise cost.
char* valhalla_optimized_route(ValhallActor* actor, const char* request_json);
char* valhalla_trace_route(ValhallActor* actor, const char* request_json);
char* valhalla_trace_attributes(ValhallActor* actor, const char* request_json);

// Free a string returned by any of the above functions.
void valhalla_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif // VALHALLA_CAPI_H
