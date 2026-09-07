#!/bin/sh
set -eu

bundle_id=$(rg -o 'PRODUCT_BUNDLE_IDENTIFIER: com\.kingtop\.apexpromoter' project.yml | wc -l | tr -d ' ')
[ "$bundle_id" = "1" ] || { echo "invalid bundle id" >&2; exit 1; }
rg -q 'MARKETING_VERSION: 1\.0\.0' project.yml
rg -q 'CURRENT_PROJECT_VERSION: [0-9]+' project.yml
rg -q 'com\.kingtop\.apexpromoter\.premium' ApexPromoter/ApexPromoter.storekit ApexPromoter/Services/EntitlementStore.swift
plutil -lint ApexPromoter/Info.plist ApexPromoter/PrivacyInfo.xcprivacy >/dev/null
echo "release configuration OK"
