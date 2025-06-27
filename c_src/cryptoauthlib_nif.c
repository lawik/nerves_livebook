#include <erl_nif.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Placeholder includes - these would be the actual cryptoauthlib headers
// #include "cryptoauthlib.h"
// #include "atca_basic.h"
// #include "atca_device.h"
// #include "atca_iface.h"

// Resource type for device handles
static ErlNifResourceType* DEVICE_RESOURCE_TYPE;

// Device handle structure
typedef struct {
    // ATCADevice device;  // Actual cryptoauthlib device handle
    void* device_handle;   // Placeholder for now
    int is_initialized;
    char device_type[32];
} device_resource_t;

// Atom definitions
static ERL_NIF_TERM atom_ok;
static ERL_NIF_TERM atom_error;
static ERL_NIF_TERM atom_nif_not_loaded;
static ERL_NIF_TERM atom_badarg;
static ERL_NIF_TERM atom_enomem;
static ERL_NIF_TERM atom_device_not_found;
static ERL_NIF_TERM atom_device_error;
static ERL_NIF_TERM atom_invalid_param;
static ERL_NIF_TERM atom_comm_fail;
static ERL_NIF_TERM atom_timeout;
static ERL_NIF_TERM atom_config;
static ERL_NIF_TERM atom_otp;
static ERL_NIF_TERM atom_data;
static ERL_NIF_TERM atom_true;
static ERL_NIF_TERM atom_false;

// Helper function to create error tuples
static ERL_NIF_TERM make_error(ErlNifEnv* env, ERL_NIF_TERM reason) {
    return enif_make_tuple2(env, atom_error, reason);
}

// Helper function to create ok tuples
static ERL_NIF_TERM make_ok(ErlNifEnv* env, ERL_NIF_TERM value) {
    return enif_make_tuple2(env, atom_ok, value);
}

// Device resource destructor
static void device_resource_dtor(ErlNifEnv* env, void* obj) {
    device_resource_t* device = (device_resource_t*)obj;
    
    if (device->is_initialized) {
        // TODO: Call actual cryptoauthlib cleanup functions
        // atcab_release();
        device->is_initialized = 0;
    }
}

// Initialize device
static ERL_NIF_TERM cryptoauthlib_init(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM device_term;
    
    // Allocate device resource
    device = enif_alloc_resource(DEVICE_RESOURCE_TYPE, sizeof(device_resource_t));
    if (!device) {
        return make_error(env, atom_enomem);
    }
    
    // Initialize device structure
    memset(device, 0, sizeof(device_resource_t));
    device->device_handle = NULL;
    device->is_initialized = 0;
    strcpy(device->device_type, "unknown");
    
    // TODO: Initialize actual cryptoauthlib device
    // ATCA_STATUS status = atcab_init(&cfg);
    // if (status != ATCA_SUCCESS) {
    //     enif_release_resource(device);
    //     return make_error(env, atom_device_error);
    // }
    
    // Simulate successful initialization for now
    device->is_initialized = 1;
    strcpy(device->device_type, "atecc608a");
    
    // Create Erlang term for the device resource
    device_term = enif_make_resource(env, device);
    enif_release_resource(device);
    
    return make_ok(env, device_term);
}

// Release device
static ERL_NIF_TERM cryptoauthlib_release(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (device->is_initialized) {
        // TODO: Call actual cryptoauthlib cleanup
        // atcab_release();
        device->is_initialized = 0;
    }
    
    return atom_ok;
}

// Get device info
static ERL_NIF_TERM cryptoauthlib_get_info(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM info_map;
    ERL_NIF_TERM keys[4];
    ERL_NIF_TERM values[4];
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    // TODO: Get actual device information
    // uint8_t serial_number[9];
    // ATCA_STATUS status = atcab_read_serial_number(serial_number);
    
    // Create mock device info for now
    keys[0] = enif_make_atom(env, "device_type");
    values[0] = enif_make_string(env, device->device_type, ERL_NIF_LATIN1);
    
    keys[1] = enif_make_atom(env, "serial_number");
    values[1] = enif_make_string(env, "0123456789ABCDEF", ERL_NIF_LATIN1);
    
    keys[2] = enif_make_atom(env, "config_locked");
    values[2] = atom_false;
    
    keys[3] = enif_make_atom(env, "data_locked");
    values[3] = atom_false;
    
    if (!enif_make_map_from_arrays(env, keys, values, 4, &info_map)) {
        return make_error(env, atom_enomem);
    }
    
    return make_ok(env, info_map);
}

// Generate random bytes
static ERL_NIF_TERM cryptoauthlib_random(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    unsigned int length;
    ErlNifBinary random_data;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[1], &length)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (length == 0 || length > 32) {
        return make_error(env, atom_invalid_param);
    }
    
    // Allocate binary for random data
    if (!enif_alloc_binary(length, &random_data)) {
        return make_error(env, atom_enomem);
    }
    
    // TODO: Generate actual random data using cryptoauthlib
    // ATCA_STATUS status = atcab_random(random_data.data);
    
    // Generate mock random data for now
    for (unsigned int i = 0; i < length; i++) {
        random_data.data[i] = rand() & 0xFF;
    }
    
    return make_ok(env, enif_make_binary(env, &random_data));
}

// Generate key pair
static ERL_NIF_TERM cryptoauthlib_genkey(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    unsigned int slot;
    ErlNifBinary public_key;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[1], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (slot > 15) {
        return make_error(env, atom_invalid_param);
    }
    
    // Allocate binary for public key (64 bytes for uncompressed key)
    if (!enif_alloc_binary(64, &public_key)) {
        return make_error(env, atom_enomem);
    }
    
    // TODO: Generate actual key using cryptoauthlib
    // ATCA_STATUS status = atcab_genkey(slot, public_key.data);
    
    // Generate mock public key for now
    for (int i = 0; i < 64; i++) {
        public_key.data[i] = (i + slot) & 0xFF;
    }
    
    return make_ok(env, enif_make_binary(env, &public_key));
}

// Get public key
static ERL_NIF_TERM cryptoauthlib_get_pubkey(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    unsigned int slot;
    ErlNifBinary public_key;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[1], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (slot > 15) {
        return make_error(env, atom_invalid_param);
    }
    
    // Allocate binary for public key
    if (!enif_alloc_binary(64, &public_key)) {
        return make_error(env, atom_enomem);
    }
    
    // TODO: Get actual public key using cryptoauthlib
    // ATCA_STATUS status = atcab_get_pubkey(slot, public_key.data);
    
    // Generate mock public key for now
    for (int i = 0; i < 64; i++) {
        public_key.data[i] = (i + slot + 0x10) & 0xFF;
    }
    
    return make_ok(env, enif_make_binary(env, &public_key));
}

// Sign digest
static ERL_NIF_TERM cryptoauthlib_sign(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    unsigned int slot;
    ErlNifBinary digest, signature;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[1], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_inspect_binary(env, argv[2], &digest)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (slot > 15) {
        return make_error(env, atom_invalid_param);
    }
    
    if (digest.size != 32) {
        return make_error(env, atom_invalid_param);
    }
    
    // Allocate binary for signature (64 bytes)
    if (!enif_alloc_binary(64, &signature)) {
        return make_error(env, atom_enomem);
    }
    
    // TODO: Sign using cryptoauthlib
    // ATCA_STATUS status = atcab_sign(slot, digest.data, signature.data);
    
    // Generate mock signature for now
    for (int i = 0; i < 64; i++) {
        signature.data[i] = (digest.data[i % 32] + slot + i) & 0xFF;
    }
    
    return make_ok(env, enif_make_binary(env, &signature));
}

// Verify signature
static ERL_NIF_TERM cryptoauthlib_verify(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    unsigned int slot;
    ErlNifBinary digest, signature;
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[1], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_inspect_binary(env, argv[2], &digest)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_inspect_binary(env, argv[3], &signature)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (slot > 15) {
        return make_error(env, atom_invalid_param);
    }
    
    if (digest.size != 32 || signature.size != 64) {
        return make_error(env, atom_invalid_param);
    }
    
    // TODO: Verify using cryptoauthlib
    // bool is_verified;
    // ATCA_STATUS status = atcab_verify_stored(slot, digest.data, signature.data, &is_verified);
    
    // Mock verification - always return true for now
    return make_ok(env, atom_true);
}

// Read from device
static ERL_NIF_TERM cryptoauthlib_read(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM zone_atom;
    unsigned int slot, offset, length;
    ErlNifBinary data;
    char zone_str[16];
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    zone_atom = argv[1];
    if (!enif_get_atom(env, zone_atom, zone_str, sizeof(zone_str), ERL_NIF_LATIN1)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[2], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[3], &offset)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[4], &length)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (length == 0 || length > 32) {
        return make_error(env, atom_invalid_param);
    }
    
    // Allocate binary for data
    if (!enif_alloc_binary(length, &data)) {
        return make_error(env, atom_enomem);
    }
    
    // TODO: Read using cryptoauthlib
    // uint8_t zone_id;
    // if (strcmp(zone_str, "config") == 0) zone_id = ATCA_ZONE_CONFIG;
    // else if (strcmp(zone_str, "otp") == 0) zone_id = ATCA_ZONE_OTP;
    // else if (strcmp(zone_str, "data") == 0) zone_id = ATCA_ZONE_DATA;
    // else return make_error(env, atom_invalid_param);
    // 
    // ATCA_STATUS status = atcab_read_zone(zone_id, slot, offset, 0, data.data, length);
    
    // Generate mock data for now
    for (unsigned int i = 0; i < length; i++) {
        data.data[i] = (i + offset + slot) & 0xFF;
    }
    
    return make_ok(env, enif_make_binary(env, &data));
}

// Write to device
static ERL_NIF_TERM cryptoauthlib_write(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM zone_atom;
    unsigned int slot, offset;
    ErlNifBinary data;
    char zone_str[16];
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    zone_atom = argv[1];
    if (!enif_get_atom(env, zone_atom, zone_str, sizeof(zone_str), ERL_NIF_LATIN1)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[2], &slot)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_get_uint(env, argv[3], &offset)) {
        return make_error(env, atom_badarg);
    }
    
    if (!enif_inspect_binary(env, argv[4], &data)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    if (data.size == 0 || data.size > 32) {
        return make_error(env, atom_invalid_param);
    }
    
    // TODO: Write using cryptoauthlib
    // uint8_t zone_id;
    // if (strcmp(zone_str, "config") == 0) zone_id = ATCA_ZONE_CONFIG;
    // else if (strcmp(zone_str, "otp") == 0) zone_id = ATCA_ZONE_OTP;
    // else if (strcmp(zone_str, "data") == 0) zone_id = ATCA_ZONE_DATA;
    // else return make_error(env, atom_invalid_param);
    // 
    // ATCA_STATUS status = atcab_write_zone(zone_id, slot, offset, 0, data.data, data.size);
    
    return atom_ok;
}

// Lock zone
static ERL_NIF_TERM cryptoauthlib_lock(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM zone_atom;
    char zone_str[16];
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    zone_atom = argv[1];
    if (!enif_get_atom(env, zone_atom, zone_str, sizeof(zone_str), ERL_NIF_LATIN1)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    // TODO: Lock using cryptoauthlib
    // uint8_t zone_id;
    // if (strcmp(zone_str, "config") == 0) zone_id = ATCA_ZONE_CONFIG;
    // else if (strcmp(zone_str, "data") == 0) zone_id = ATCA_ZONE_DATA;
    // else return make_error(env, atom_invalid_param);
    // 
    // ATCA_STATUS status = atcab_lock(zone_id, 0);
    
    return atom_ok;
}

// Check if zone is locked
static ERL_NIF_TERM cryptoauthlib_is_locked(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
    device_resource_t* device;
    ERL_NIF_TERM zone_atom;
    char zone_str[16];
    
    if (!enif_get_resource(env, argv[0], DEVICE_RESOURCE_TYPE, (void**)&device)) {
        return make_error(env, atom_badarg);
    }
    
    zone_atom = argv[1];
    if (!enif_get_atom(env, zone_atom, zone_str, sizeof(zone_str), ERL_NIF_LATIN1)) {
        return make_error(env, atom_badarg);
    }
    
    if (!device->is_initialized) {
        return make_error(env, atom_device_error);
    }
    
    // TODO: Check lock status using cryptoauthlib
    // bool is_locked;
    // uint8_t zone_id;
    // if (strcmp(zone_str, "config") == 0) zone_id = ATCA_ZONE_CONFIG;
    // else if (strcmp(zone_str, "data") == 0) zone_id = ATCA_ZONE_DATA;
    // else return make_error(env, atom_invalid_param);
    // 
    // ATCA_STATUS status = atcab_is_locked(zone_id, &is_locked);
    
    // Mock - return false for now
    return make_ok(env, atom_false);
}

// NIF function array
static ErlNifFunc nif_funcs[] = {
    {"init", 0, cryptoauthlib_init, 0},
    {"release", 1, cryptoauthlib_release, 0},
    {"get_info", 1, cryptoauthlib_get_info, 0},
    {"random", 2, cryptoauthlib_random, 0},
    {"genkey", 2, cryptoauthlib_genkey, 0},
    {"get_pubkey", 2, cryptoauthlib_get_pubkey, 0},
    {"sign", 3, cryptoauthlib_sign, 0},
    {"verify", 4, cryptoauthlib_verify, 0},
    {"read", 5, cryptoauthlib_read, 0},
    {"write", 5, cryptoauthlib_write, 0},
    {"lock", 2, cryptoauthlib_lock, 0},
    {"is_locked", 2, cryptoauthlib_is_locked, 0}
};

// NIF initialization
static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM load_info) {
    // Initialize atoms
    atom_ok = enif_make_atom(env, "ok");
    atom_error = enif_make_atom(env, "error");
    atom_nif_not_loaded = enif_make_atom(env, "nif_not_loaded");
    atom_badarg = enif_make_atom(env, "badarg");
    atom_enomem = enif_make_atom(env, "enomem");
    atom_device_not_found = enif_make_atom(env, "device_not_found");
    atom_device_error = enif_make_atom(env, "device_error");
    atom_invalid_param = enif_make_atom(env, "invalid_param");
    atom_comm_fail = enif_make_atom(env, "comm_fail");
    atom_timeout = enif_make_atom(env, "timeout");
    atom_config = enif_make_atom(env, "config");
    atom_otp = enif_make_atom(env, "otp");
    atom_data = enif_make_atom(env, "data");
    atom_true = enif_make_atom(env, "true");
    atom_false = enif_make_atom(env, "false");
    
    // Create resource type for device handles
    DEVICE_RESOURCE_TYPE = enif_open_resource_type(
        env, NULL, "cryptoauthlib_device",
        device_resource_dtor,
        ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
        NULL
    );
    
    if (!DEVICE_RESOURCE_TYPE) {
        return -1;
    }
    
    return 0;
}

// NIF module definition
ERL_NIF_INIT(Elixir.NervesLivebook.Cryptoauthlib, nif_funcs, load, NULL, NULL, NULL)