# dynamically inject ota.mk into device tree
cat << 'EOF' > device/xiaomi/creek/features.mk
# OTA url for future updates
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    lineage.updater.uri=$(OTA_URL) \
    persist.ota.url=$(OTA_URL)

# Inherit FastCharge configurations
$(call inherit-product, packages/apps/FastCharge/fastcharge.mk)
EOF

# Update AndroidProducts.mk string occurrences using sed
sed -i 's/lineage_creek/custom_creek/g' device/xiaomi/creek/AndroidProducts.mk

# Rename the main makefile
mv device/xiaomi/creek/lineage_creek.mk device/xiaomi/creek/custom_creek.mk

# Update PRODUCT_NAME inside custom_creek.mk
sed -i 's/PRODUCT_NAME\s*:=\s*lineage_creek/PRODUCT_NAME             := custom_creek/g' device/xiaomi/creek/custom_creek.mk

# Update PRODUCT_BRAND inside custom_creek.mk
sed -i 's/PRODUCT_BRAND\s*:=\s*POCO/PRODUCT_BRAND              := Xaiomi/g' device/xiaomi/creek/custom_creek.mk
