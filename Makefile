APP_NAME = Hotnews
EXECUTABLE_NAME = Macnews
WIDGET_NAME = HotnewsWidget
BUNDLE_DIR = $(APP_NAME).app
CONTENTS_DIR = $(BUNDLE_DIR)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources
PLUGINS_DIR = $(CONTENTS_DIR)/PlugIns
WIDGET_BUNDLE_DIR = $(PLUGINS_DIR)/$(WIDGET_NAME).appex
WIDGET_CONTENTS_DIR = $(WIDGET_BUNDLE_DIR)/Contents
WIDGET_MACOS_DIR = $(WIDGET_CONTENTS_DIR)/MacOS

.PHONY: build app install run test clean

build:
	swift build -c release

app: build
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(WIDGET_MACOS_DIR)"
	cp ".build/release/$(EXECUTABLE_NAME)" "$(MACOS_DIR)/$(APP_NAME)"
	cp ".build/release/$(WIDGET_NAME)" "$(WIDGET_MACOS_DIR)/$(WIDGET_NAME)"
	cp "AppIcon.icns" "$(RESOURCES_DIR)/AppIcon.icns"
	cp -R ".build/release/$(EXECUTABLE_NAME)_$(EXECUTABLE_NAME).bundle" "$(RESOURCES_DIR)/"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>CFBundleDevelopmentRegion</key>' \
		'    <string>en</string>' \
		'    <key>CFBundleExecutable</key>' \
		'    <string>Hotnews</string>' \
		'    <key>CFBundleIconFile</key>' \
		'    <string>AppIcon</string>' \
		'    <key>CFBundleIdentifier</key>' \
		'    <string>com.lucianmarin.macnews</string>' \
		'    <key>CFBundleInfoDictionaryVersion</key>' \
		'    <string>6.0</string>' \
		'    <key>CFBundleName</key>' \
		'    <string>Hotnews</string>' \
		'    <key>CFBundleDisplayName</key>' \
		'    <string>Hotnews</string>' \
		'    <key>CFBundlePackageType</key>' \
		'    <string>APPL</string>' \
		'    <key>CFBundleShortVersionString</key>' \
		'    <string>1.1</string>' \
		'    <key>CFBundleVersion</key>' \
		'    <string>3</string>' \
		'    <key>CFBundleURLTypes</key>' \
		'    <array>' \
		'        <dict>' \
		'            <key>CFBundleURLName</key>' \
		'            <string>com.lucianmarin.macnews.url</string>' \
		'            <key>CFBundleURLSchemes</key>' \
		'            <array>' \
		'                <string>hotnews</string>' \
		'            </array>' \
		'        </dict>' \
		'    </array>' \
		'    <key>LSMinimumSystemVersion</key>' \
		'    <string>14.0</string>' \
		'    <key>NSHighResolutionCapable</key>' \
		'    <true/>' \
		'    <key>NSPrincipalClass</key>' \
		'    <string>NSApplication</string>' \
		'</dict>' \
		'</plist>' > "$(CONTENTS_DIR)/Info.plist"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>CFBundleDevelopmentRegion</key>' \
		'    <string>en</string>' \
		'    <key>CFBundleDisplayName</key>' \
		'    <string>Hotnews</string>' \
		'    <key>CFBundleExecutable</key>' \
		'    <string>$(WIDGET_NAME)</string>' \
		'    <key>CFBundleIdentifier</key>' \
		'    <string>com.lucianmarin.macnews.widget</string>' \
		'    <key>CFBundleInfoDictionaryVersion</key>' \
		'    <string>6.0</string>' \
		'    <key>CFBundleName</key>' \
		'    <string>$(WIDGET_NAME)</string>' \
		'    <key>CFBundlePackageType</key>' \
		'    <string>XPC!</string>' \
		'    <key>CFBundleShortVersionString</key>' \
		'    <string>1.0</string>' \
		'    <key>CFBundleSupportedPlatforms</key>' \
		'    <array>' \
		'        <string>MacOSX</string>' \
		'    </array>' \
		'    <key>CFBundleVersion</key>' \
		'    <string>1</string>' \
		'    <key>LSMinimumSystemVersion</key>' \
		'    <string>14.0</string>' \
		'    <key>NSExtension</key>' \
		'    <dict>' \
		'        <key>NSExtensionPointIdentifier</key>' \
		'        <string>com.apple.widgetkit-extension</string>' \
		'    </dict>' \
		'</dict>' \
		'</plist>' > "$(WIDGET_CONTENTS_DIR)/Info.plist"
	touch "$(WIDGET_BUNDLE_DIR)" "$(BUNDLE_DIR)"
	codesign --force --sign - --entitlements "Sources/HotnewsWidget/HotnewsWidget.entitlements" "$(WIDGET_BUNDLE_DIR)"
	codesign --force --sign - "$(BUNDLE_DIR)"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "$(BUNDLE_DIR)" 2>/dev/null || true

install: app
	rm -rf "/Applications/$(BUNDLE_DIR)"
	cp -R "$(BUNDLE_DIR)" "/Applications/$(BUNDLE_DIR)"
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R "/Applications/$(BUNDLE_DIR)" 2>/dev/null || true
	@pluginkit -a "/Applications/$(BUNDLE_DIR)/Contents/PlugIns/$(WIDGET_NAME).appex" 2>/dev/null || true

run: app
	open "$(BUNDLE_DIR)"

test:
	swift test

clean:
	swift package clean
	rm -rf "$(BUNDLE_DIR)"
