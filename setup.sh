#!/bin/bash

# CA Officials iOS App Setup Script
# This script sets up the Xcode project using XcodeGen

set -e

echo "=========================================="
echo "CA Officials iOS App Setup"
echo "=========================================="
echo ""

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "XcodeGen is not installed."
    echo ""
    echo "Install using one of these methods:"
    echo "  brew install xcodegen"
    echo "  mint install yonaskolb/XcodeGen"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Open CAOfficials.xcodeproj"
echo "2. Set your Development Team in Signing & Capabilities"
echo "3. Update SupabaseConfig.swift with your credentials"
echo "4. Build and run!"
echo ""
echo "To merge into California Voters:"
echo "1. Copy the Officials/ folder to CaliforniaVotersIOS/Modules/"
echo "2. Copy the Connect/ folder to CaliforniaVotersIOS/Modules/"
echo "3. Merge Core files into existing managers"
echo "4. Update navigation to include Officials and Connect tabs"
echo ""
