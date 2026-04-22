#!/bin/bash

# Quick script to build a secured release APK
# Make sure you have created the keystore and key.properties first!

set -e  # Exit on error

echo "=========================================="
echo "Building Secured Release APK"
echo "=========================================="
echo ""

# Check if key.properties exists
if [ ! -f "android/key.properties" ]; then
    echo "❌ Error: key.properties not found!"
    echo ""
    echo "Please create it first:"
    echo "1. Copy android/key.properties.example to android/key.properties"
    echo "2. Fill in your keystore details"
    echo "3. Or run: cd android && ./create-keystore.sh"
    exit 1
fi

# Check if keystore exists
KEYSTORE_PATH=$(grep "storeFile=" android/key.properties | cut -d'=' -f2)
KEYSTORE_PATH="${KEYSTORE_PATH#../}"  # Remove ../ prefix if present

if [ ! -f "android/$KEYSTORE_PATH" ]; then
    echo "❌ Error: Keystore file not found at android/$KEYSTORE_PATH"
    echo "Please create the keystore first:"
    echo "  cd android && ./create-keystore.sh"
    exit 1
fi

echo "✅ Keystore configuration found"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build release APK
echo ""
echo "🔨 Building release APK..."
flutter build apk --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "📱 APK location:"
    echo "   build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    echo "📊 APK size:"
    ls -lh build/app/outputs/flutter-apk/app-release.apk | awk '{print "   " $5}'
    echo ""
    echo "🔒 The APK is signed and secured with:"
    echo "   - Code obfuscation (ProGuard)"
    echo "   - Resource shrinking"
    echo "   - Code shrinking"
    echo "   - Cryptographic signing"
    echo ""
else
    echo ""
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi







