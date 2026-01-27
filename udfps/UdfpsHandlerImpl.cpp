/*
 * Copyright (C) 2024 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "UdfpsHandler.cybert"

#include "include/UdfpsHandler.h"

#include <android-base/logging.h>
#include <fcntl.h>
#include <unistd.h>

#define BACKLIGHT_PATH "/sys/class/leds/lcd-backlight/brightness"

#define HBM_ON_MAGIC_VALUE  "4294967294"
#define HBM_OFF_MAGIC_VALUE "4294967293"

class CybertUdfpsHandler : public UdfpsHandler {
public:
    void init(fingerprint_device_t* device) override {
        mDevice = device;
        LOG(INFO) << "Cybert UDFPS handler initialized";
    }

    void onFingerDown(uint32_t x, uint32_t y,
                      float /* minor */, float /* major */) override {
        LOG(INFO) << "Finger down: x=" << x << " y=" << y;
        setHbm(true);
    }

    void onFingerUp() override {
        LOG(INFO) << "Finger up";
        setHbm(false);
    }

    void onAcquired(int32_t result, int32_t /* vendorCode */) override {
        // Optional: turn off HBM only on GOOD
        if (result == FINGERPRINT_ACQUIRED_GOOD) {
            setHbm(false);
        }
    }

    void cancel() override {
        LOG(INFO) << "UDFPS cancel";
        setHbm(false);
    }

private:
    fingerprint_device_t* mDevice = nullptr;

    void setHbm(bool enable) {
        const char* value = enable ? HBM_ON_MAGIC_VALUE : HBM_OFF_MAGIC_VALUE;

        int fd = open(BACKLIGHT_PATH, O_WRONLY | O_CLOEXEC);
        if (fd < 0) {
            LOG(ERROR) << "Failed to open backlight path";
            return;
        }

        if (write(fd, value, strlen(value)) < 0) {
            LOG(ERROR) << "Failed to write HBM value";
        }

        close(fd);
    }
};

static UdfpsHandler* create() {
    return new CybertUdfpsHandler();
}

static void destroy(UdfpsHandler* handler) {
    delete handler;
}

extern "C" UdfpsHandlerFactory UDFPS_HANDLER_FACTORY = {
    .create = create,
    .destroy = destroy,
};
