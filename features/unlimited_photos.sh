#!/bin/bash

FRAMEWORKS="frameworks/base"

echo "================================================="
echo " Injecting PixelPropsUtils to frameworks/base... "
echo "================================================="

# 1. Add PixelPropsUtils.java
mkdir -p "$FRAMEWORKS/core/java/com/android/internal/util/lineage"

cat << 'EOF' > "$FRAMEWORKS/core/java/com/android/internal/util/lineage/PixelPropsUtils.java"
package com.android.internal.util.lineage;

import android.os.Build;
import android.util.Log;

import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

public class PixelPropsUtils {
    private static final String TAG = "PixelPropsUtils";
    private static final String PACKAGE_GPHOTOS = "com.google.android.apps.photos";

    private static final Map<String, Object> propsToSpoof;

    static {
        propsToSpoof = new HashMap<>();
        propsToSpoof.put("BRAND", "google");
        propsToSpoof.put("MANUFACTURER", "Google");
        propsToSpoof.put("DEVICE", "marlin");
        propsToSpoof.put("PRODUCT", "marlin");
        propsToSpoof.put("MODEL", "Pixel XL");
        propsToSpoof.put("FINGERPRINT", "google/marlin/marlin:10/QP1A.191005.007.A3/5972272:user/release-keys");
    }

    public static void setProps(String packageName) {
        if (packageName == null) return;

        if (packageName.equals(PACKAGE_GPHOTOS)) {
            Log.d(TAG, "Spoofing Pixel XL for Google Photos");
            for (Map.Entry<String, Object> prop : propsToSpoof.entrySet()) {
                setPropValue(prop.getKey(), prop.getValue());
            }
        }
    }

    private static void setPropValue(String key, Object value) {
        try {
            Field field = Build.class.getDeclaredField(key);
            field.setAccessible(true);
            field.set(null, value);
            field.setAccessible(false);
        } catch (NoSuchFieldException | IllegalAccessException e) {
            Log.e(TAG, "Failed to spoof prop: " + key, e);
        }
    }
}
EOF

# 2. Hook Application.java
APP_JAVA="$FRAMEWORKS/core/java/android/app/Application.java"

if ! grep -q "PixelPropsUtils.setProps" "$APP_JAVA"; then
    sed -i '/mLoadedApk = ContextImpl.getImpl(context).mPackageInfo;/a \        com.android.internal.util.lineage.PixelPropsUtils.setProps(mLoadedApk.getPackageName());' "$APP_JAVA"
    echo " -> Application.java hooked successfully."
else
    echo " -> Application.java already hooked."
fi

echo "Done!"