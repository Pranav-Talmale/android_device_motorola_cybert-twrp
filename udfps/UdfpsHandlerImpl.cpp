/*
 * Copyright (C) 2024 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#define LOG_TAG "UdfpsHandler.cybert"

#include "include/UdfpsHandler.h"

#include <android-base/logging.h>
#include <fcntl.h>
#include <thread>
#include <unistd.h>

#define BACKLIGHT_PATH "/sys/class/leds/lcd-backlight/hbm_mode"

#define HBM_ON_MAGIC_VALUE  "1"
#define HBM_OFF_MAGIC_VALUE "0"

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

    void onAcquired(int32_t result, int32_t vendorCode) override {
        // Do NOT turn off HBM here - this fires DURING capture, not after!
        // Turning off HBM here interrupts the optical sensor mid-capture.
        // The framework will call onFingerUp when the capture session ends.
        LOG(DEBUG) << "onAcquired: result=" << result << " vendorCode=" << vendorCode;
    }

    void cancel() override {
        LOG(INFO) << "UDFPS cancel";
        setHbm(false);
    }

private:
    fingerprint_device_t* mDevice = nullptr;
    std::atomic<int> mTimeoutToken{0};
    std::atomic<bool> mHbmActive{false};

    void setHbm(bool enable) {
        // Skip redundant state changes
        if (mHbmActive.load() == enable) {
            LOG(DEBUG) << "setHbm: Already " << (enable ? "ON" : "OFF") << ", skipping";
            return;
        }

        const char* value = enable ? HBM_ON_MAGIC_VALUE : HBM_OFF_MAGIC_VALUE;
        LOG(INFO) << "setHbm: " << (enable ? "ON" : "OFF");

        int fd = open(BACKLIGHT_PATH, O_WRONLY | O_CLOEXEC);
        if (fd < 0) {
            LOG(ERROR) << "Failed to open backlight path: " << strerror(errno);
            return;
        }

        ssize_t written = write(fd, value, strlen(value));
        if (written < 0) {
            LOG(ERROR) << "Failed to write HBM value: " << strerror(errno);
        } else {
            mHbmActive.store(enable);
            LOG(INFO) << "HBM " << (enable ? "enabled" : "disabled") << " successfully";
        }

        close(fd);

        /* 
         * Safety Timeout with Cancellation Token:
         * Prevents stuck HBM if onFingerUp is never called.
         * Token ensures old timeouts don't fire after new finger down events.
         * 800ms allows sufficient time for enrollment captures.
         */
        if (enable) {
            int currentToken = ++mTimeoutToken;
            std::thread([this, currentToken]() {
                usleep(400000); // 400ms - Reduced to minimize white patch persistence
                if (mTimeoutToken.load() == currentToken && mHbmActive.load()) {
                    LOG(INFO) << "Safety Timeout: Forcing HBM OFF";
                    this->setHbm(false);
                }
            }).detach();
        } else {
            mTimeoutToken++; // Invalidate any pending timeout
        }
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
