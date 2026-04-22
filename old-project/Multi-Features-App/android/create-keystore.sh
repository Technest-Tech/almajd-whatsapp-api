#!/bin/bash

# Script to create a keystore for signing the Android release APK
# Run this script from the android directory

echo "=========================================="
echo "Creating Android Release Keystore"
echo "=========================================="
echo ""

# Check if keystore already exists
if [ -f "keystore.jks" ]; then
    echo "⚠️  WARNING: keystore.jks already exists!"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Keystore creation cancelled."
        exit 1
    fi
    rm keystore.jks
fi

# Get keystore information
echo "Please provide the following information for your keystore:"
echo ""

read -p "Keystore password (min 6 characters): " STORE_PASSWORD
if [ ${#STORE_PASSWORD} -lt 6 ]; then
    echo "❌ Error: Password must be at least 6 characters"
    exit 1
fi

read -p "Key password (can be same as keystore password): " KEY_PASSWORD
if [ -z "$KEY_PASSWORD" ]; then
    KEY_PASSWORD=$STORE_PASSWORD
fi

read -p "Key alias (default: upload): " KEY_ALIAS
if [ -z "$KEY_ALIAS" ]; then
    KEY_ALIAS="upload"
fi

read -p "Your name (for certificate): " NAME
read -p "Organization unit (e.g., IT): " OU
read -p "Organization (e.g., Almajd Academy): " ORG
read -p "City: " CITY
read -p "State/Province: " STATE
read -p "Country code (2 letters, e.g., SA): " COUNTRY

# Validate country code
if [ ${#COUNTRY} -ne 2 ]; then
    echo "❌ Error: Country code must be exactly 2 letters"
    exit 1
fi

# Create keystore
echo ""
echo "Creating keystore..."
keytool -genkey -v \
    -keystore keystore.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias "$KEY_ALIAS" \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$NAME, OU=$OU, O=$ORG, L=$CITY, ST=$STATE, C=$COUNTRY"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Keystore created successfully!"
    echo ""
    echo "📝 Next steps:"
    echo "1. Create key.properties file with the following content:"
    echo ""
    echo "   storePassword=$STORE_PASSWORD"
    echo "   keyPassword=$KEY_PASSWORD"
    echo "   keyAlias=$KEY_ALIAS"
    echo "   storeFile=../keystore.jks"
    echo ""
    echo "2. Save it as: android/key.properties"
    echo "3. Make sure keystore.jks and key.properties are NOT committed to git"
    echo "4. Build your release APK with: flutter build apk --release"
    echo ""
else
    echo ""
    echo "❌ Error: Failed to create keystore"
    exit 1
fi







