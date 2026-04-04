import Foundation

enum XcodeProjectGeneratorError: LocalizedError {
    case failedToCreateDirectory(URL)
    case failedToWriteFile(URL)
    case failedToCopyTestFile(URL)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let url):
            return "Failed to create directory at \(url.path)"
        case .failedToWriteFile(let url):
            return "Failed to write file at \(url.path)"
        case .failedToCopyTestFile(let url):
            return "Failed to copy test file from \(url.path)"
        }
    }
}

struct XcodeProjectGenerator {

    static func generate(testFileURL: URL, projectDir: URL) throws -> URL {
        let fm = FileManager.default

        let xcodeprojURL = projectDir
            .appendingPathComponent("FrameHeroCaptureTests.xcodeproj")
        let pbxprojURL = xcodeprojURL
            .appendingPathComponent("project.pbxproj")
        let schemesDir = xcodeprojURL
            .appendingPathComponent("xcshareddata")
            .appendingPathComponent("xcschemes")
        let schemeURL = schemesDir
            .appendingPathComponent("FrameHeroCaptureTests.xcscheme")
        let uiTestsDir = projectDir
            .appendingPathComponent("UITests")
        let destTestFile = uiTestsDir
            .appendingPathComponent("FrameHeroCaptureTests.swift")

        // Create directories
        for dir in [xcodeprojURL, schemesDir, uiTestsDir] {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw XcodeProjectGeneratorError.failedToCreateDirectory(dir)
            }
        }

        // Write project.pbxproj
        do {
            try pbxprojContents.write(to: pbxprojURL, atomically: true, encoding: .utf8)
        } catch {
            throw XcodeProjectGeneratorError.failedToWriteFile(pbxprojURL)
        }

        // Write scheme
        do {
            try schemeContents.write(to: schemeURL, atomically: true, encoding: .utf8)
        } catch {
            throw XcodeProjectGeneratorError.failedToWriteFile(schemeURL)
        }

        // Copy test file
        do {
            if fm.fileExists(atPath: destTestFile.path) {
                try fm.removeItem(at: destTestFile)
            }
            try fm.copyItem(at: testFileURL, to: destTestFile)
        } catch {
            throw XcodeProjectGeneratorError.failedToCopyTestFile(testFileURL)
        }

        return xcodeprojURL
    }

    // MARK: - Hardcoded UUIDs

    private static let rootObject          = "AA000001000000000000000A"
    private static let mainGroup           = "AA000002000000000000000A"
    private static let uiTestsGroup        = "AA000003000000000000000A"
    private static let productsGroup       = "AA000004000000000000000A"
    private static let nativeTarget        = "AA000005000000000000000A"
    private static let productRef          = "AA000006000000000000000A"
    private static let sourcesBuildPhase   = "AA000007000000000000000A"
    private static let buildFileRef        = "AA000008000000000000000A"
    private static let fileRef             = "AA000009000000000000000A"
    private static let projectBuildConfig  = "AA00000A000000000000000A"
    private static let targetBuildConfig   = "AA00000B000000000000000A"
    private static let projectConfigList   = "AA00000C000000000000000A"
    private static let targetConfigList    = "AA00000D000000000000000A"

    // MARK: - project.pbxproj

    private static let pbxprojContents = """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {
        \t};
        \tobjectVersion = 56;
        \tobjects = {

        /* Begin PBXBuildFile section */
        \t\t\(buildFileRef) /* FrameHeroCaptureTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = \(fileRef) /* FrameHeroCaptureTests.swift */; };
        /* End PBXBuildFile section */

        /* Begin PBXFileReference section */
        \t\t\(fileRef) /* FrameHeroCaptureTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = FrameHeroCaptureTests.swift; sourceTree = "<group>"; };
        \t\t\(productRef) /* FrameHeroCaptureTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = FrameHeroCaptureTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
        /* End PBXFileReference section */

        /* Begin PBXGroup section */
        \t\t\(mainGroup) = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(uiTestsGroup) /* UITests */,
        \t\t\t\t\(productsGroup) /* Products */,
        \t\t\t);
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t\(uiTestsGroup) /* UITests */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(fileRef) /* FrameHeroCaptureTests.swift */,
        \t\t\t);
        \t\t\tpath = UITests;
        \t\t\tsourceTree = "<group>";
        \t\t};
        \t\t\(productsGroup) /* Products */ = {
        \t\t\tisa = PBXGroup;
        \t\t\tchildren = (
        \t\t\t\t\(productRef) /* FrameHeroCaptureTests.xctest */,
        \t\t\t);
        \t\t\tname = Products;
        \t\t\tsourceTree = "<group>";
        \t\t};
        /* End PBXGroup section */

        /* Begin PBXNativeTarget section */
        \t\t\(nativeTarget) /* FrameHeroCaptureTests */ = {
        \t\t\tisa = PBXNativeTarget;
        \t\t\tbuildConfigurationList = \(targetConfigList) /* Build configuration list for PBXNativeTarget "FrameHeroCaptureTests" */;
        \t\t\tbuildPhases = (
        \t\t\t\t\(sourcesBuildPhase) /* Sources */,
        \t\t\t);
        \t\t\tbuildRules = (
        \t\t\t);
        \t\t\tdependencies = (
        \t\t\t);
        \t\t\tname = FrameHeroCaptureTests;
        \t\t\tproductName = FrameHeroCaptureTests;
        \t\t\tproductReference = \(productRef) /* FrameHeroCaptureTests.xctest */;
        \t\t\tproductType = "com.apple.product-type.bundle.ui-testing";
        \t\t};
        /* End PBXNativeTarget section */

        /* Begin PBXProject section */
        \t\t\(rootObject) /* Project object */ = {
        \t\t\tisa = PBXProject;
        \t\t\tbuildConfigurationList = \(projectConfigList) /* Build configuration list for PBXProject "FrameHeroCaptureTests" */;
        \t\t\tcompatibilityVersion = "Xcode 14.0";
        \t\t\tdevelopmentRegion = en;
        \t\t\thasScannedForEncodings = 0;
        \t\t\tknownRegions = (
        \t\t\t\ten,
        \t\t\t\tBase,
        \t\t\t);
        \t\t\tmainGroup = \(mainGroup);
        \t\t\tproductRefGroup = \(productsGroup) /* Products */;
        \t\t\tprojectDirPath = "";
        \t\t\tprojectRoot = "";
        \t\t\ttargets = (
        \t\t\t\t\(nativeTarget) /* FrameHeroCaptureTests */,
        \t\t\t);
        \t\t};
        /* End PBXProject section */

        /* Begin PBXSourcesBuildPhase section */
        \t\t\(sourcesBuildPhase) /* Sources */ = {
        \t\t\tisa = PBXSourcesBuildPhase;
        \t\t\tbuildActionMask = 2147483647;
        \t\t\tfiles = (
        \t\t\t\t\(buildFileRef) /* FrameHeroCaptureTests.swift in Sources */,
        \t\t\t);
        \t\t\trunOnlyForDeploymentPostprocessing = 0;
        \t\t};
        /* End PBXSourcesBuildPhase section */

        /* Begin XCBuildConfiguration section */
        \t\t\(projectBuildConfig) /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
        \t\t\t\tCLANG_ENABLE_MODULES = YES;
        \t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
        \t\t\t\tONLY_ACTIVE_ARCH = YES;
        \t\t\t\tSDKROOT = iphoneos;
        \t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        \t\t\(targetBuildConfig) /* Debug */ = {
        \t\t\tisa = XCBuildConfiguration;
        \t\t\tbuildSettings = {
        \t\t\t\tCODE_SIGN_STYLE = Automatic;
        \t\t\t\tGENERATE_INFOPLIST_FILE = YES;
        \t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.framehero.CaptureTests;
        \t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
        \t\t\t\tSWIFT_VERSION = 5.0;
        \t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
        \t\t\t};
        \t\t\tname = Debug;
        \t\t};
        /* End XCBuildConfiguration section */

        /* Begin XCConfigurationList section */
        \t\t\(projectConfigList) /* Build configuration list for PBXProject "FrameHeroCaptureTests" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t\(projectBuildConfig) /* Debug */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        \t\t\(targetConfigList) /* Build configuration list for PBXNativeTarget "FrameHeroCaptureTests" */ = {
        \t\t\tisa = XCConfigurationList;
        \t\t\tbuildConfigurations = (
        \t\t\t\t\(targetBuildConfig) /* Debug */,
        \t\t\t);
        \t\t\tdefaultConfigurationIsVisible = 0;
        \t\t\tdefaultConfigurationName = Debug;
        \t\t};
        /* End XCConfigurationList section */

        \t};
        \trootObject = \(rootObject) /* Project object */;
        }

        """

    // MARK: - Scheme

    private static let schemeContents = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Scheme
           LastUpgradeVersion = "1500"
           version = "1.7">
           <TestAction
              buildConfiguration = "Debug"
              selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
              selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
              shouldUseLaunchSchemeArgsEnv = "YES"
              shouldAutocreateTestPlan = "YES">
              <Testables>
                 <TestableReference
                    skipped = "NO">
                    <BuildableReference
                       BuildableIdentifier = "primary"
                       BlueprintIdentifier = "\(nativeTarget)"
                       BuildableName = "FrameHeroCaptureTests.xctest"
                       BlueprintName = "FrameHeroCaptureTests"
                       ReferencedContainer = "container:FrameHeroCaptureTests.xcodeproj">
                    </BuildableReference>
                 </TestableReference>
              </Testables>
           </TestAction>
        </Scheme>

        """
}
