import Foundation
import PathKit
import ProjectSpec
import Spectre
import XcodeProj
import XCTest
import Yams
import TestSupport
import Version

class SpecLoadingTests: XCTestCase {

    func testSpecLoaderDuplicateImports() {
        describe {
            $0.it("merges each file only once") {
                let path = fixturePath + "duplicated_include/duplicated_import_sut.yml"
                let project = try loadSpec(path: path)

                try expect(project.fileGroups) == ["First", "Second", "Third"]

                let sutTarget = project.targets.first
                try expect(sutTarget?.sources) == [TargetSource(path: "template")]
                try expect(sutTarget?.preBuildScripts) == [BuildScript(script: .script("swiftlint"), name: "Swiftlint")]
            }
        }
    }

    func testSpecLoader() {
        describe {
            $0.it("merges includes") {
                let path = fixturePath + "include_test.yml"
                let project = try loadSpec(path: path, variables: [:])

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3", "MY_SETTING4": "${SETTING4}"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"], dependencies: [Dependency(type: .package(products: []), reference: "Yams")]),
                    Target(name: "NewTarget", type: .application, platform: .iOS, sources: ["template", "target"]),
                ]
            }

            $0.it("merges includes with additional") {
                let path = fixturePath + "include_test.yml"
                let project = try loadSpec(path: path, variables: ["INCLUDE_ADDITIONAL_YAML": "YES"])

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3", "MY_SETTING4": "${SETTING4}", "MY_SETTING5": "ADDITIONAL"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"], dependencies: [Dependency(type: .package(products: []), reference: "SwiftPM"), Dependency(type: .package(products: []), reference: "Yams")]),
                    Target(name: "NewTarget", type: .application, platform: .iOS, sources: ["template", "target"]),
                ]
            }

            $0.it("merges includes without additional by environment variable") {
                let path = fixturePath + "include_test.yml"
                let project = try loadSpec(path: path, variables: ["INCLUDE_ADDITIONAL_YAML": "NO"])

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3", "MY_SETTING4": "${SETTING4}"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"], dependencies: [Dependency(type: .package(products: []), reference: "Yams")]),
                    Target(name: "NewTarget", type: .application, platform: .iOS, sources: ["template", "target"]),
                ]
            }

            $0.it("expands directories") {
                let path = fixturePath + "paths_test.yml"
                let project = try loadSpec(path: path)

                try expect(project.configFiles) == [
                    "IncludedConfig": "paths_test/config",
                    "NewConfig": "config",
                    "RecursiveConfig": "paths_test/recursive_test/config",
                ]

                try expect(project.options) == SpecOptions(
                    carthageBuildPath: "paths_test/recursive_test/carthage_build",
                    carthageExecutablePath: "carthage_executable"
                )

                try expect(project.projectReferences) == [
                    ProjectReference(name: "ProjX", path: "TestProject/Project.xcodeproj"),
                ]

                try expect(project.aggregateTargets) == [
                    AggregateTarget(
                        name: "IncludedAggregateTarget",
                        targets: ["IncludedTarget"],
                        configFiles: ["Config": "paths_test/config"],
                        buildScripts: [BuildScript(script: .path("paths_test/buildScript"))]
                    ),
                    AggregateTarget(
                        name: "NewAggregateTarget",
                        targets: ["NewTarget"],
                        configFiles: ["Config": "config"],
                        buildScripts: [BuildScript(script: .path("buildScript"))]
                    ),
                    AggregateTarget(
                        name: "RecursiveAggregateTarget",
                        targets: ["RecursiveTarget"],
                        configFiles: ["Config": "paths_test/recursive_test/config"],
                        buildScripts: [BuildScript(script: .path("paths_test/recursive_test/buildScript"))]
                    ),
                ]

                try expect(project.targets) == [
                    Target(
                        name: "IncludedTarget",
                        type: .application,
                        platform: .tvOS,
                        configFiles: ["Config": "paths_test/config"],
                        sources: [
                            "paths_test/simplesource",
                            TargetSource(path: "paths_test/source", excludes: ["file"]),
                        ],
                        dependencies: [Dependency(type: .framework, reference: "paths_test/Framework")],
                        info: Plist(path: "paths_test/info"),
                        entitlements: Plist(path: "paths_test/entitlements"),
                        preBuildScripts: [BuildScript(script: .path("paths_test/preBuildScript"))],
                        postCompileScripts: [BuildScript(script: .path("paths_test/postCompileScript"))],
                        postBuildScripts: [BuildScript(script: .path("paths_test/postBuildScript"))],
                        scheme: TargetScheme(testPlans: [.init(path: "paths_test/TestPlan.xctestplan")])
                    ),
                    Target(
                        name: "NewTarget",
                        type: .application,
                        platform: .iOS,
                        configFiles: ["Config": "config"],
                        sources: [
                            "paths_test/template_source",
                            "source",
                        ],
                        dependencies: [Dependency(type: .framework, reference: "Framework")],
                        info: Plist(path: "info"),
                        entitlements: Plist(path: "entitlements"),
                        preBuildScripts: [BuildScript(script: .path("preBuildScript"))],
                        postCompileScripts: [BuildScript(script: .path("postCompileScript"))],
                        postBuildScripts: [BuildScript(script: .path("postBuildScript"))]
                    ),
                    Target(
                        name: "RecursiveTarget",
                        type: .application,
                        platform: .macOS,
                        configFiles: ["Config": "paths_test/recursive_test/config"],
                        sources: ["paths_test/recursive_test/source"],
                        dependencies: [Dependency(type: .framework, reference: "paths_test/recursive_test/Framework")],
                        info: Plist(path: "paths_test/recursive_test/info"),
                        entitlements: Plist(path: "paths_test/recursive_test/entitlements"),
                        preBuildScripts: [BuildScript(script: .path("paths_test/recursive_test/prebuildScript"))],
                        postCompileScripts: [BuildScript(script: .path("paths_test/recursive_test/postCompileScript"))],
                        postBuildScripts: [BuildScript(script: .path("paths_test/recursive_test/postBuildScript"))]
                    ),
                    Target(
                        name: "app",
                        type: .application,
                        platform: .macOS,
                        sources: ["paths_test/same_relative_path_test/source"],
                        dependencies: [
                            Dependency(type: .target, reference: "target1"),
                            Dependency(type: .target, reference: "target2")
                        ]
                    ),
                    Target(
                        name: "target1",
                        type: .framework,
                        platform: .macOS,
                        sources: ["paths_test/same_relative_path_test/parent1/same/target1/source"]
                    ),
                    Target(
                        name: "target2",
                        type: .framework,
                        platform: .macOS,
                        sources: ["paths_test/same_relative_path_test/parent2/same/target2/source"]
                    )
                ]

                try expect(project.schemes) == [
                    Scheme(
                        name: "Scheme",
                        build: .init(targets: [.init(target: "NewTarget")]),
                        test: .init(testPlans: [.init(path: "paths_test/TestPlan.xctestplan")])
                    )
                ]

                try expect(project.packages) == [
                    "LocalPackage": .local(path: "paths_test/relative_local_package/LocalPackage", group: nil, excludeFromProject: false),
                ]

                try expect(project.fileGroups.contains("paths_test/relative_file_groups/TestFile.md")) == true
            }

            $0.it("respects directory expansion preference") {
                let path = fixturePath + "legacy_paths_test.yml"
                let project = try loadSpec(path: path)

                try expect(project.configFiles) == [
                    "IncludedConfig": "config",
                ]

                try expect(project.options) == SpecOptions(
                    carthageBuildPath: "carthage_build",
                    carthageExecutablePath: "carthage_executable"
                )

                try expect(project.aggregateTargets) == [
                    AggregateTarget(
                        name: "IncludedAggregateTarget",
                        targets: ["IncludedTarget"],
                        configFiles: ["Config": "config"],
                        buildScripts: [BuildScript(script: .path("buildScript"))]
                    ),
                ]

                try expect(project.targets) == [
                    Target(
                        name: "IncludedTarget",
                        type: .application,
                        platform: .tvOS,
                        configFiles: ["Config": "config"],
                        sources: ["source"],
                        dependencies: [Dependency(type: .framework, reference: "Framework")],
                        info: Plist(path: "info"),
                        entitlements: Plist(path: "entitlements"),
                        preBuildScripts: [BuildScript(script: .path("preBuildScript"))],
                        postCompileScripts: [BuildScript(script: .path("postCompileScript"))],
                        postBuildScripts: [BuildScript(script: .path("postBuildScript"))]
                    ),
                ]
            }

            $0.it("parses yaml types") {
                let path = fixturePath + "yaml.yml"
                let dictionary = try loadYamlDictionary(path: path)
                let expectedDictionary: [String: Any] = [
                    "true": true,
                    "false": false,
                    "yes": true,
                    "no": false,
                    "yesQuote": "YES",
                    "noQuote": "NO",
                    "int": 1,
                    "intQuote": "1",
                    "float": 3.2,
                    "floatQuote": "10.10",
                    "string": "hello",
                    "stringQuote": "hello",
                    "space": " ",
                    "empty": "",
                    "emptyQuote": "",
                    "emptyDictionary": [String: Any](),
                    "arrayLiteral": [1, 2],
                    "arrayList": [1, 2],
                ]
                for (key, expectedValue) in expectedDictionary {
                    guard let parsedValue = dictionary[key] else {
                        throw failure("\(key) does not exist")
                    }
                    if String(describing: expectedValue) != String(describing: parsedValue) {
                        throw failure("\(key): \(parsedValue) does not equal \(expectedValue)")
                    }
                }
                if !(dictionary as NSDictionary).isEqual(expectedDictionary as NSDictionary) {
                    throw failure("parsed yaml types don't match:\n\nParsed:\n\t\(dictionary.map { "\($0.key): \($0.value)" }.joined(separator: "\n\t"))\nExpected:\n\t\(expectedDictionary.map { "\($0.key): \($0.value)" }.joined(separator: "\n\t"))")
                }
            }

            $0.it("expands variables") {
                let path = fixturePath + "variables_test.yml"
                let project = try loadSpec(path: path, variables: [
                    "SETTING1": "ENV VALUE1",
                    "SETTING4": "ENV VALUE4",
                    "variable": "doesWin",
                ])

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "ENV VALUE1", "MY_SETTING2": "VALUE2", "MY_SETTING4": "ENV VALUE4"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING1": "VALUE1"]),
                ]
                try expect(project.targets.last?.sources) == ["SomeTarget", "doesWin", "templateVariable"]
            }
        }
    }

    func testSpecLoaderLoadingJSON() {
        describe {
            $0.it("merges includes") {
                let path = fixturePath + "include_test.json"
                let project = try loadSpec(path: path)

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3", "MY_SETTING4": "${SETTING4}"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"]),
                    Target(name: "NewTarget", type: .application, platform: .iOS),
                ]
            }
        }
    }

    func testSpecWarningValidation() {
        describe {
            var path: Path!
            $0.before {
                path = Path(components: [NSTemporaryDirectory(), "\(NSUUID().uuidString).yaml"])

            }
            $0.after {
                try? FileManager.default.removeItem(atPath: path.string)
            }
            $0.it("fails validating warnings for deprecated placeholder usage") {
                let dictionary: [String: Any] = [
                    "name": "TestSpecWarningValidation",
                    "templates": [
                        "Framework": [
                            "type": "framework",
                            "sources": ["${target_name}/${platform}/Sources"],
                        ],
                    ],
                    "targets": [
                        "Framework": [
                            "type": "framework",
                            "platform": "iOS",
                            "templates": ["Framework"],
                        ],
                    ],
                ]
                try? Yams.dump(object: dictionary).write(toFile: path.string, atomically: true, encoding: .utf8)
                let specLoader = SpecLoader(version: "1.1.0")
                do {
                    _ = try specLoader.loadProject(path: path)
                } catch {
                    throw failure("\(error)")
                }
            }

            $0.it("successfully validates warnings for new placeholder usage") {
                let dictionary: [String: Any] = [
                    "name": "TestSpecWarningValidation",
                    "templates": [
                        "Framework": [
                            "type": "framework",
                            "sources": ["${target_name}/${platform}/Sources"],
                        ],
                    ],
                    "targets": [
                        "Framework": [
                            "type": "framework",
                            "platform": "iOS",
                            "templates": ["Framework"],
                        ],
                    ],
                ]
                try? Yams.dump(object: dictionary).write(toFile: path.string, atomically: true, encoding: .utf8)
                let specLoader = SpecLoader(version: "1.1.0")
                do {
                    _ = try specLoader.loadProject(path: path)
                } catch {
                    throw failure("\(error)")
                }
                do {
                    try specLoader.validateProjectDictionaryWarnings()
                } catch {
                    throw failure("Expected to not throw a validation error. Got: \(error)")
                }
            }
        }
    }

    func testProjectSpecParser() {
        let validTarget: [String: Any] = ["type": "application", "platform": "iOS"]
        let validBreakpoint: [String: Any] = ["type": "Exception", "scope": "All", "stopOnStyle": "Catch"]
        let invalid = "invalid"

        describe {

            $0.it("fails with incorrect platform") {
                var target = validTarget
                target["platform"] = invalid
                try expectTargetError(target, .unknownTargetPlatform(invalid))
            }

            $0.it("fails with incorrect product type") {
                var target = validTarget
                target["type"] = invalid
                try expectTargetError(target, .unknownTargetType(invalid))
            }

            $0.it("fails with invalid dependency") {
                var target = validTarget
                target["dependencies"] = [[invalid: "name"]]
                try expectTargetError(target, .invalidDependency([invalid: "name"]))
            }

            $0.it("fails with incorrect breakpoint type") {
                var breakpoint = validBreakpoint
                breakpoint["type"] = invalid
                try expectBreakpointError(breakpoint, .unknownBreakpointType(invalid))
            }

            $0.it("fails with incorrect breakpoint scope") {
                var target = validBreakpoint
                target["scope"] = invalid
                try expectBreakpointError(target, .unknownBreakpointScope(invalid))
            }

            $0.it("fails with incorrect breakpoint stop on style") {
                var target = validBreakpoint
                target["stopOnStyle"] = invalid
                try expectBreakpointError(target, .unknownBreakpointStopOnStyle(invalid))
            }

            $0.it("fails with incorrect breakpoint action type") {
                var breakpoint = validBreakpoint
                breakpoint["actions"] = [["type": invalid]]
                try expectBreakpointError(breakpoint, .unknownBreakpointActionType(invalid))
            }

            $0.it("fails with incorrect breakpoint action conveyance type") {
                var breakpoint = validBreakpoint
                breakpoint["actions"] = [["type": "Log", "conveyanceType": invalid]]
                try expectBreakpointError(breakpoint, .unknownBreakpointActionConveyanceType(invalid))
            }

            $0.it("fails with incorrect breakpoint action sound name") {
                var breakpoint = validBreakpoint
                breakpoint["actions"] = [["type": "Sound", "sound": invalid]]
                try expectBreakpointError(breakpoint, .unknownBreakpointActionSoundName(invalid))
            }

            $0.it("parses breakpoints") {
                let breakpointDictionaries = [
                    ["type": "File", "path": "Foo.swift", "line": 7, "column": 14, "condition": "bar == nil"],
                    ["type": "Exception", "scope": "All", "stopOnStyle": "Catch"],
                    ["type": "SwiftError", "enabled": false],
                    ["type": "OpenGLError", "ignoreCount": 2],
                    ["type": "Symbolic", "symbol": "UIViewAlertForUnsatisfiableConstraints", "module": "UIKitCore"],
                    ["type": "IDEConstraintError", "continueAfterRunningActions": true],
                    ["type": "IDETestFailure"],
                ]

                let project = try getProjectSpec(["breakpoints": breakpointDictionaries])

                let expectedBreakpoints = [
                    Breakpoint(type: .file(path: "Foo.swift", line: 7, column: 14), condition: "bar == nil"),
                    Breakpoint(type: .exception(.init(scope: .all, stopOnStyle: .catch))),
                    Breakpoint(type: .swiftError, enabled: false),
                    Breakpoint(type: .openGLError, ignoreCount: 2),
                    Breakpoint(type: .symbolic(symbol: "UIViewAlertForUnsatisfiableConstraints", module: "UIKitCore")),
                    Breakpoint(type: .ideConstraintError, continueAfterRunningActions: true),
                    Breakpoint(type: .ideTestFailure),
                ]

                try expect(project.breakpoints) == expectedBreakpoints
            }

            $0.it("parses breakpoint actions") {
                var breakpointDicationary = validBreakpoint
                breakpointDicationary["actions"] = [
                    ["type": "DebuggerCommand", "command": "po $arg1"],
                    ["type": "Log", "message": "message", "conveyanceType": "speak"],
                    ["type": "ShellCommand", "path": "script.sh", "arguments": "argument1, argument2", "waitUntilDone": true],
                    ["type": "GraphicsTrace"],
                    ["type": "AppleScript", "script": #"display alert "Hello!""#],
                    ["type": "Sound", "sound": "Hero"],
                ]

                let breakpoint = try Breakpoint(jsonDictionary: breakpointDicationary)

                let expectedActions: [Breakpoint.Action] = [
                    .debuggerCommand("po $arg1"),
                    .log(.init(message: "message", conveyanceType: .speak)),
                    .shellCommand(path: "script.sh", arguments: "argument1, argument2", waitUntilDone: true),
                    .graphicsTrace,
                    .appleScript(#"display alert "Hello!""#),
                    .sound(.hero),
                ]

                try expect(breakpoint.actions) == expectedActions
            }

            $0.it("parses sources") {
                var targetDictionary1 = validTarget
                targetDictionary1["sources"] = [
                    "sourceString",
                    ["path": "sourceObject"],
                    ["path": "sourceWithFlagsArray", "compilerFlags": ["-Werror"]],
                    ["path": "sourceWithFlagsString", "compilerFlags": "-Werror -Wextra"],
                    ["path": "sourceWithExcludes", "excludes": ["Foo.swift"]],
                    ["path": "sourceWithFileType", "type": "file"],
                    ["path": "sourceWithGroupType", "type": "group"],
                    ["path": "sourceWithFolderType", "type": "folder"],
                    ["path": "sourceWithResourceTags", "resourceTags": ["tag1", "tag2"]],
                ]
                var targetDictionary2 = validTarget
                targetDictionary2["sources"] = "source3"

                let target1 = try Target(name: "test", jsonDictionary: targetDictionary1)
                let target2 = try Target(name: "test", jsonDictionary: targetDictionary2)

                let target1SourcesExpect = [
                    TargetSource(path: "sourceString"),
                    TargetSource(path: "sourceObject"),
                    TargetSource(path: "sourceWithFlagsArray", compilerFlags: ["-Werror"]),
                    TargetSource(path: "sourceWithFlagsString", compilerFlags: ["-Werror", "-Wextra"]),
                    TargetSource(path: "sourceWithExcludes", excludes: ["Foo.swift"]),
                    TargetSource(path: "sourceWithFileType", type: .file),
                    TargetSource(path: "sourceWithGroupType", type: .group),
                    TargetSource(path: "sourceWithFolderType", type: .folder),
                    TargetSource(path: "sourceWithResourceTags", resourceTags: ["tag1", "tag2"]),
                ]

                try expect(target1.sources) == target1SourcesExpect
                try expect(target2.sources) == ["source3"]
            }

            $0.it("parses target dependencies") {
                var targetDictionary = validTarget
                targetDictionary["dependencies"] = [
                    ["target": "name", "embed": false, "platformFilter": "all"],
                    ["target": "project/name", "embed": false, "platformFilter": "macOS"],
                    ["carthage": "name", "findFrameworks": true, "platformFilter": "iOS"],
                    ["carthage": "name", "findFrameworks": true, "linkType": "static"],
                    ["framework": "path", "weak": true],
                    ["sdk": "Contacts.framework"],
                    [
                        "sdk": "Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCTest.framework",
                        "root": "DEVELOPER_DIR",
                    ],
                    ["target": "conditionalMatch", "platforms": ["iOS"]],
                    ["target": "conditionalMiss", "platforms": ["watchOS"]],
                ]
                let target = try Target(name: "test", jsonDictionary: targetDictionary)
                try expect(target.dependencies.count) == 8
                try expect(target.dependencies[0]) == Dependency(type: .target, reference: "name", embed: false, platformFilter: .all)
                try expect(target.dependencies[1]) == Dependency(type: .target, reference: "project/name", embed: false, platformFilter: .macOS)
                try expect(target.dependencies[2]) == Dependency(type: .carthage(findFrameworks: true, linkType: .dynamic), reference: "name", platformFilter: .iOS)
                try expect(target.dependencies[3]) == Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "name")
                try expect(target.dependencies[4]) == Dependency(type: .framework, reference: "path", weakLink: true)
                try expect(target.dependencies[5]) == Dependency(type: .sdk(root: nil), reference: "Contacts.framework")
                try expect(target.dependencies[6]) == Dependency(type: .sdk(root: "DEVELOPER_DIR"), reference: "Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCTest.framework")
                try expect(target.dependencies[7]) == Dependency(type: .target, reference: "conditionalMatch", platforms: [.iOS])
            }

            $0.it("parses info plist") {
                var targetDictionary = validTarget
                targetDictionary["info"] = [
                    "path": "Info.plist",
                    "properties": [
                        "CFBundleName": "MyAppName",
                        "UIBackgroundModes": ["fetch"],
                    ],
                ]

                let target = try Target(name: "", jsonDictionary: targetDictionary)
                try expect(target.info) == Plist(path: "Info.plist", attributes: [
                    "CFBundleName": "MyAppName",
                    "UIBackgroundModes": ["fetch"],
                ])
            }

            $0.it("parses entitlement plist") {
                var targetDictionary = validTarget
                targetDictionary["entitlements"] = [
                    "path": "app.entitlements",
                    "properties": [
                        "com.apple.security.application-groups": "com.group",
                    ],
                ]

                let target = try Target(name: "", jsonDictionary: targetDictionary)
                try expect(target.entitlements) == Plist(path: "app.entitlements", attributes: [
                    "com.apple.security.application-groups": "com.group",
                ])
            }

            $0.it("parses cross platform targets") {
                let targetDictionary: [String: Any] = [
                    "platform": ["iOS", "tvOS"],
                    "deploymentTarget": ["iOS": 9.0, "tvOS": "10.0"],
                    "type": "framework",
                    "sources": ["Framework", "Framework ${platform}"],
                    "settings": ["SETTING": "value_${platform}"],
                ]

                let project = try getProjectSpec(["targets": ["Framework": targetDictionary]])
                var target_iOS = Target(name: "Framework_iOS", type: .framework, platform: .iOS)
                var target_tvOS = Target(name: "Framework_tvOS", type: .framework, platform: .tvOS)

                target_iOS.sources = ["Framework", "Framework iOS"]
                target_tvOS.sources = ["Framework", "Framework tvOS"]
                target_iOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_iOS"]
                target_tvOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_tvOS"]
                target_iOS.deploymentTarget = Version(major: 9, minor: 0, patch: 0)
                target_tvOS.deploymentTarget = Version(major: 10, minor: 0, patch: 0)

                try expect(project.targets) == [target_iOS, target_tvOS]
            }
            
            $0.it("parses no platform fallbacks to auto if we are using supported destinations") {
                let targetDictionary: [String: Any] = [
                    "type": "framework",
                    "supportedDestinations": ["iOS", "tvOS"]
                ]

                let project = try getProjectSpec(["targets": ["Framework": targetDictionary]])
                let target = Target(name: "Framework", type: .framework, platform: .auto)
                
                try expect(project.targets) == [target]
            }
            
            $0.it("parses no platform fails if we are not using supported destinations") {
                let expectedError = SpecParsingError.unknownTargetPlatform("")
                
                let projectDictionary: [String: Any] = [
                    "name": "test",
                    "targets": ["target1": [
                        "type": "application"
                    ] as [String : Any]]
                ]
                
                try expectError(expectedError) {
                    _ = try Project(jsonDictionary: projectDictionary)
                }
            }
            
            $0.it("parses supported destinations with macCatalyst but not iOS, we add iOS") {
                let targetDictionary: [String: Any] = [
                    "type": "framework",
                    "supportedDestinations": ["macCatalyst"]
                ]
                
                let project = try getProjectSpec(["targets": ["Framework": targetDictionary]])
                let target = Target(name: "Framework", type: .framework, platform: .auto)
                
                try expect(project.targets) == [target]
                try expect(project.targets.first?.supportedDestinations) == [.macCatalyst, .iOS]
            }
            
            $0.it("invalid target platform because platform is an array and supported destinations is in use") {
                let expectedError = SpecParsingError.invalidTargetPlatformAsArray
                
                let projectDictionary: [String: Any] = [
                    "name": "test",
                    "targets": ["target1": [
                        "type": "application",
                        "platform": ["iOS", "tvOS"],
                        "supportedDestinations": ["iOS", "tvOS"]
                    ] as [String : Any]]
                ]
                
                try expectError(expectedError) {
                    _ = try Project(jsonDictionary: projectDictionary)
                }
            }
            
            $0.it("parses target templates") {

                let targetDictionary: [String: Any] = [
                    "deploymentTarget": "1.2.0",
                    "sources": ["targetSource"],
                    "templates": ["temp2", "temp"],
                    "templateAttributes": [
                        "source": "replacedSource",
                    ],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "platform": "iOS",
                            "sources": [
                                "templateSource",
                                ["path": "Sources/${target_name}"],
                            ],
                        ],
                        "temp2": [
                            "type": "framework",
                            "platform": "tvOS",
                            "deploymentTarget": "1.1.0",
                            "configFiles": [
                                "debug": "Configs/${target_name}/debug.xcconfig",
                                "release": "Configs/${target_name}/release.xcconfig",
                            ],
                            "sources": ["${source}"],
                        ],
                    ],
                ])

                let target = project.targets.first!
                try expect(target.type) == .framework // uses value
                try expect(target.platform) == .iOS // uses latest value
                try expect(target.deploymentTarget) == Version("1.2.0") // keeps value
                try expect(target.sources) == ["replacedSource", "templateSource", "Sources/Framework", "targetSource"] // merges array in order and replace ${target_name}
                try expect(target.configFiles["debug"]) == "Configs/Framework/debug.xcconfig" // replaces $target_name
                try expect(target.configFiles["release"]) == "Configs/Framework/release.xcconfig" // replaces ${target_name}
            }

            $0.it("parses nested target templates") {

                let targetDictionary: [String: Any] = [
                    "deploymentTarget": "1.2.0",
                    "sources": ["targetSource"],
                    "templates": ["temp2"],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "type": "framework",
                            "platform": "iOS",
                            "sources": ["nestedTemplateSource1"],
                        ],
                        "temp1": [
                            "type": "application",
                            "sources": ["nestedTemplateSource2"],
                        ],
                        "temp2": [
                            "platform": "tvOS",
                            "deploymentTarget": "1.1.0",
                            "configFiles": ["debug": "Configs/${target_name}/debug.xcconfig"],
                            "templates": ["temp", "temp1"],
                            "sources": ["templateSource"],
                        ],
                    ],
                ])

                let target = project.targets.first!
                try expect(target.type) == .application // uses value of last nested template
                try expect(target.platform) == .tvOS // uses latest value
                try expect(target.deploymentTarget) == Version("1.2.0") // keeps value
                try expect(target.sources) == ["nestedTemplateSource1", "nestedTemplateSource2", "templateSource", "targetSource"] // merges array in order
                try expect(target.configFiles["debug"]) == "Configs/Framework/debug.xcconfig" // replaces $target_name
            }

            $0.it("parses complex nested target templates") {

                let targetDictionary: [String: Any] = [
                    "type": "framework",
                    "platform": "iOS",
                    "templates": ["temp"],
                    "sources": ["target"],
                    "templateAttributes": [
                        "temp": "temp-by-target",
                        "a": "a-by-target",
                        "b": "b-by-target", // This should win over attributes defined in template "temp"
                    ],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "templates": ["a", "d"],
                            "sources": ["temp", "${temp}"],
                            "templateAttributes": [
                                "b": "b-by-temp",
                                "c": "c-by-temp",
                                "d": "d-by-temp",
                            ],
                        ],
                        "a": [
                            "templates": ["b", "c"],
                            "sources": ["a", "${a}"],
                            "templateAttributes": [
                                "c": "c-by-a",
                            ],
                        ],
                        "b": [
                            "sources": ["b", "${b}"],
                        ],
                        "c": [
                            "sources": ["c", "${c}"],
                        ],
                        "d": [
                            "sources": ["d", "${d}"],
                            "templates": ["e"],
                            "templateAttributes": [
                                "e": "e-by-d",
                            ],
                        ],
                        "e": [
                            "sources": ["e", "${e}"],
                        ],

                    ],
                ])

                let target = project.targets.first!
                try expect(target.type) == .framework // uses value of last nested template
                try expect(target.platform) == .iOS // uses latest value
                try expect(target.sources) == ["b", "b-by-target",
                                               "c", "c-by-temp",
                                               "a", "a-by-target",
                                               "e", "e-by-d",
                                               "d", "d-by-temp",
                                               "temp", "temp-by-target",
                                               "target"] // merges array in order
            }

            $0.it("parses nested target templates with cycle") {

                let targetDictionary: [String: Any] = [
                    "deploymentTarget": "1.2.0",
                    "sources": ["targetSource"],
                    "templates": ["temp2"],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "type": "framework",
                            "platform": "iOS",
                            "templates": ["temp1"],
                            "sources": ["nestedTemplateSource1"],
                        ],
                        "temp1": [
                            "platform": "macOS",
                            "templates": ["temp2"],
                            "sources": ["nestedTemplateSource2"],
                        ],
                        "temp2": [
                            "platform": "tvOS",
                            "deploymentTarget": "1.1.0",
                            "configFiles": ["debug": "Configs/${target_name}/debug.xcconfig"],
                            "templates": ["temp", "temp1"],
                            "sources": ["templateSource"],
                        ],
                    ],
                ])

                let target = project.targets.first!
                try expect(target.type) == .framework // uses value
                try expect(target.platform) == .tvOS // uses latest value
                try expect(target.deploymentTarget) == Version("1.2.0") // keeps value
                try expect(target.sources) == ["nestedTemplateSource2", "nestedTemplateSource1", "templateSource", "targetSource"] // merges array in order
                try expect(target.configFiles["debug"]) == "Configs/Framework/debug.xcconfig" // replaces $target_name
            }

            $0.it("parses cross platform target templates") {

                let project = try getProjectSpec([
                    "targets": [
                        "Framework": [
                            "type": "framework",
                            "templates": ["temp"],
                        ],
                    ],
                    "targetTemplates": [
                        "temp": [
                            "platform": ["iOS", "tvOS"],
                        ],
                    ],
                ])

                let iOSTarget = project.targets.first { $0.platform == .iOS }
                let tvOSTarget = project.targets.first { $0.platform == .tvOS }
                try expect(iOSTarget?.type) == .framework
                try expect(tvOSTarget?.type) == .framework
            }

            $0.it("parses platform specific templates") {

                let project = try getProjectSpec([
                    "targets": [
                        "Framework": [
                            "type": "framework",
                            "platform": ["iOS", "tvOS"],
                            "templates": ["${platform}"],
                        ],
                    ],
                    "targetTemplates": [
                        "iOS": [
                            "sources": "A",
                        ],
                        "tvOS": [
                            "sources": "B",
                        ],
                    ],
                ])

                let iOSTarget = project.targets.first { $0.platform == .iOS }
                let tvOSTarget = project.targets.first { $0.platform == .tvOS }
                try expect(iOSTarget?.sources) == ["A"]
                try expect(tvOSTarget?.sources) == ["B"]
            }

            $0.it("parses aggregate targets") {
                let dictionary: [String: Any] = [
                    "targets": ["target_1", "target_2"],
                    "settings": ["SETTING": "VALUE"],
                    "configFiles": ["debug": "file.xcconfig"],
                ]

                let project = try getProjectSpec(["aggregateTargets": ["AggregateTarget": dictionary]])
                let expectedTarget = AggregateTarget(name: "AggregateTarget", targets: ["target_1", "target_2"], settings: ["SETTING": "VALUE"], configFiles: ["debug": "file.xcconfig"])
                try expect(project.aggregateTargets) == [expectedTarget]
            }

            $0.it("parses target schemes") {
                var targetDictionary = validTarget
                targetDictionary["scheme"] = [
                    "testTargets": ["t1", ["name": "t2"]],
                    "configVariants": ["dev", "app-store"],
                    "commandLineArguments": [
                        "ENV1": true,
                    ],
                    "gatherCoverageData": true,
                    "coverageTargets": ["t1"],
                    "storeKitConfiguration": "Configuration.storekit",
                    "language": "en",
                    "region": "US",
                    "disableMainThreadChecker": true,
                    "stopOnEveryMainThreadCheckerIssue": true,
                    "disableThreadPerformanceChecker": true,
                    "environmentVariables": [
                        "TEST_VAR": "TEST_VAL",
                    ],
                    "preActions": [
                        [
                            "script": "dothing",
                            "name": "Do Thing",
                            "settingsTarget": "test",
                        ],
                    ],
                    "postActions": [
                        [
                            "script": "hello",
                        ],
                    ],
                    "management": [
                        "shared": false,
                        "isShown": true,
                        "orderHint": 10
                    ],
                ]

                let target = try Target(name: "test", jsonDictionary: targetDictionary)

                let scheme = TargetScheme(
                    testTargets: ["t1", "t2"],
                    configVariants: ["dev", "app-store"],
                    gatherCoverageData: true,
                    coverageTargets: ["t1"],
                    storeKitConfiguration: "Configuration.storekit",
                    language: "en",
                    region: "US",
                    disableMainThreadChecker: true,
                    stopOnEveryMainThreadCheckerIssue: true,
                    disableThreadPerformanceChecker: true,
                    commandLineArguments: ["ENV1": true],
                    environmentVariables: [XCScheme.EnvironmentVariable(variable: "TEST_VAR", value: "TEST_VAL", enabled: true)],
                    preActions: [.init(name: "Do Thing", script: "dothing", settingsTarget: "test")],
                    postActions: [.init(name: "Run Script", script: "hello")],
                    management: Scheme.Management(shared: false, orderHint: 10, isShown: true)
                )

                try expect(target.scheme) == scheme
            }

            $0.it("parses schemes") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "parallelizeBuild": false,
                        "buildImplicitDependencies": false,
                        "runPostActionsOnFailure": true,
                        "targets": [
                            "Target1": "all",
                            "Target2": "testing",
                            "Target3": "none",
                            "Target4": ["testing": true],
                            "Target5": ["testing": false],
                            "Target6": ["test", "analyze"],
                            "ExternalProject/Target7": ["run"],
                        ],
                        "preActions": [
                            [
                                "script": "echo Before Build",
                                "name": "Before Build",
                                "settingsTarget": "Target1",
                            ],
                        ],
                    ],
                    "run": [
                        "config": "debug",
                        "launchAutomaticallySubstyle": 2,
                        "enableGPUFrameCaptureMode": "disabled",
                        "storeKitConfiguration": "Configuration.storekit",
                        "disableThreadPerformanceChecker": true,
                    ],
                    "test": [
                        "config": "debug",
                        "targets": [
                            "Target1",
                            [
                                "name": "ExternalProject/Target2",
                                "parallelizable": true,
                                "skipped": true,
                                "location": "test.gpx",
                                "randomExecutionOrder": true,
                                "skippedTests": ["Test/testExample()"],
                            ],
                        ],
                        "gatherCoverageData": true,
                        "disableMainThreadChecker": true,
                        "stopOnEveryMainThreadCheckerIssue": true,
                        "testPlans": [
                            [
                                "path": "Path/Plan.xctestplan"
                            ],
                            [
                                "path": "Path/Plan2.xctestplan"
                            ]
                        ],
                        "preferredScreenCaptureFormat": "screenshots",
                    ],
                    "management": [
                        "isShown": false,
                        "orderHint": 4
                    ],
                ]
                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)
                let expectedTargets: [Scheme.BuildTarget] = [
                    Scheme.BuildTarget(target: "Target1", buildTypes: BuildType.all),
                    Scheme.BuildTarget(target: "Target2", buildTypes: [.testing, .analyzing]),
                    Scheme.BuildTarget(target: "Target3", buildTypes: []),
                    Scheme.BuildTarget(target: "Target4", buildTypes: [.testing]),
                    Scheme.BuildTarget(target: "Target5", buildTypes: []),
                    Scheme.BuildTarget(target: "Target6", buildTypes: [.testing, .analyzing]),
                    Scheme.BuildTarget(target: "ExternalProject/Target7", buildTypes: [.running]),
                ]
                try expect(scheme.name) == "Scheme"
                try expect(scheme.build.targets) == expectedTargets
                try expect(scheme.build.preActions.first?.script) == "echo Before Build"
                try expect(scheme.build.preActions.first?.name) == "Before Build"
                try expect(scheme.build.preActions.first?.settingsTarget) == "Target1"

                try expect(scheme.build.parallelizeBuild) == false
                try expect(scheme.build.buildImplicitDependencies) == false
                try expect(scheme.build.runPostActionsOnFailure) == true

                let expectedRun = Scheme.Run(
                    config: "debug",
                    enableGPUFrameCaptureMode: .disabled,
                    disableThreadPerformanceChecker: true,
                    launchAutomaticallySubstyle: "2",
                    storeKitConfiguration: "Configuration.storekit"
                )
                try expect(scheme.run) == expectedRun

                let expectedTest = Scheme.Test(
                    config: "debug",
                    gatherCoverageData: true,
                    disableMainThreadChecker: true,
                    targets: [
                        "Target1",
                        Scheme.Test.TestTarget(
                            targetReference: "ExternalProject/Target2",
                            randomExecutionOrder: true,
                            parallelizable: true,
                            location: "test.gpx",
                            skipped: true,
                            skippedTests: ["Test/testExample()"]
                        ),
                    ],
                    testPlans: [
                        .init(path: "Path/Plan.xctestplan"),
                        .init(path: "Path/Plan2.xctestplan")
                    ],
                    preferredScreenCaptureFormat: .screenshots
                )
                try expect(scheme.test) == expectedTest

                let expectedManagement = Scheme.Management(shared: true, orderHint: 4, isShown: false)
                try expect(scheme.management) == expectedManagement
            }

            $0.it("parses alternate test schemes") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "targets": ["Target1": "all"],
                    ],
                    "test": [
                        "config": "debug",
                        "targets": [
                            "Target1",
                            [
                                "name": "ExternalProject/Target2",
                                "parallelizable": true,
                                "location": "New York, NY, USA",
                                "randomExecutionOrder": true,
                                "selectedTests": ["Test/testExample()"],
                            ],
                        ],
                        "gatherCoverageData": true,
                        "disableMainThreadChecker": true,
                        "stopOnEveryMainThreadCheckerIssue": true,
                    ],
                    "management": [
                        "isShown": false
                    ],
                ]
                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)

                let expectedTest = Scheme.Test(
                    config: "debug",
                    gatherCoverageData: true,
                    disableMainThreadChecker: true,
                    targets: [
                        "Target1",
                        Scheme.Test.TestTarget(
                            targetReference: "ExternalProject/Target2",
                            randomExecutionOrder: true,
                            parallelizable: true,
                            location: "New York, NY, USA",
                            selectedTests: ["Test/testExample()"]
                        ),
                    ]
                )
                try expect(scheme.test) == expectedTest

                let expectedManagement = Scheme.Management(shared: true, orderHint: nil, isShown: false)
                try expect(scheme.management) == expectedManagement
            }

            $0.it("parses schemes variables") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "targets": ["Target1": "all"],
                    ],
                    "run": [
                        "environmentVariables": [
                            ["variable": "BOOL_TRUE", "value": true],
                            ["variable": "BOOL_YES", "value": "YES"],
                            ["variable": "ENVIRONMENT", "value": "VARIABLE"],
                            ["variable": "OTHER_ENV_VAR", "value": "VAL", "isEnabled": false],
                        ],
                        "launchAutomaticallySubstyle": "2",
                        "storeKitConfiguration": "Configuration.storekit",
                    ],
                    "test": [
                        "environmentVariables": [
                            "BOOL_TRUE": true,
                            "BOOL_YES": "YES",
                            "TEST": "VARIABLE",
                        ],
                    ],
                    "profile": [
                        "config": "Release",
                    ],
                ]

                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)

                let expectedRunVariables = [
                    XCScheme.EnvironmentVariable(variable: "BOOL_TRUE", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "BOOL_YES", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "ENVIRONMENT", value: "VARIABLE", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "OTHER_ENV_VAR", value: "VAL", enabled: false),
                ]

                let expectedTestVariables = [
                    XCScheme.EnvironmentVariable(variable: "BOOL_TRUE", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "BOOL_YES", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "TEST", value: "VARIABLE", enabled: true),
                ]

                try expect(scheme.run?.environmentVariables) == expectedRunVariables
                try expect(scheme.run?.launchAutomaticallySubstyle) == "2"
                try expect(scheme.run?.storeKitConfiguration) == "Configuration.storekit"
                try expect(scheme.test?.environmentVariables) == expectedTestVariables
                try expect(scheme.profile?.config) == "Release"
                try expect(scheme.profile?.environmentVariables.isEmpty) == true
            }

            $0.it("parses alternate schemes variables") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "targets": ["Target1": "all"],
                    ],
                    "run": [
                        "launchAutomaticallySubstyle": 2, // Both integer and string supported
                        "storeKitConfiguration": "Configuration.storekit",
                    ],
                ]

                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)
                try expect(scheme.run?.launchAutomaticallySubstyle) == "2"
                try expect(scheme.run?.storeKitConfiguration) == "Configuration.storekit"
            }

            $0.it("parses scheme templates") {
                let targetDictionary: [String: Any] = [
                    "deploymentTarget": "1.2.0",
                    "sources": ["targetSource"],
                    "templates": ["temp2", "temp"],
                    "templateAttributes": [
                        "source": "replacedSource",
                    ],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "platform": "iOS",
                            "sources": [
                                "templateSource",
                                ["path": "Sources/${target_name}"],
                            ],
                        ],
                        "temp2": [
                            "type": "framework",
                            "platform": "tvOS",
                            "deploymentTarget": "1.1.0",
                            "configFiles": [
                                "debug": "Configs/${target_name}/debug.xcconfig",
                                "release": "Configs/${target_name}/release.xcconfig",
                            ],
                            "sources": ["${source}"],
                        ],
                    ],
                    "schemeTemplates": [
                        "base_scheme": [
                            "build": [
                                "parallelizeBuild": false,
                                "buildImplicitDependencies": false,
                                "runPostActionsOnFailure": true,
                                "targets": [
                                    "Target${name_1}": "all",
                                    "Target2": "testing",
                                    "Target${name_3}": "none",
                                    "Target4": ["testing": true],
                                    "Target5": ["testing": false],
                                    "Target6": ["test", "analyze"],
                                ],
                                "preActions": [
                                    [
                                        "script": "${pre-action-name}",
                                        "name": "Before Build ${scheme_name}",
                                        "settingsTarget": "Target${name_1}",
                                    ],
                                ],
                            ],
                            "run": [
                                "storeKitConfiguration": "Configuration.storekit",
                            ],
                            "test": [
                                "config": "debug",
                                "targets": [
                                    "Target${name_1}",
                                    [
                                        "name": "Target2",
                                        "parallelizable": true,
                                        "randomExecutionOrder": true,
                                        "skippedTests": ["Test/testExample()"],
                                    ],
                                ],
                                "gatherCoverageData": true,
                                "disableMainThreadChecker": true,
                                "stopOnEveryMainThreadCheckerIssue": false,
                            ],
                            "management": [
                                "shared": false,
                                "orderHint": 8
                            ],
                        ],
                    ],
                    "schemes": [
                        "temp2": [
                            "templates": ["base_scheme"],
                            "templateAttributes": [
                                "pre-action-name": "modified-name",
                                "name_1": "FirstTarget",
                                "name_3": "ThirdTarget",
                            ],
                        ],
                    ],
                ])

                let scheme = project.schemes.first!
                let expectedTargets: [Scheme.BuildTarget] = [
                    Scheme.BuildTarget(target: "TargetFirstTarget", buildTypes: BuildType.all),
                    Scheme.BuildTarget(target: "Target2", buildTypes: [.testing, .analyzing]),
                    Scheme.BuildTarget(target: "TargetThirdTarget", buildTypes: []),
                    Scheme.BuildTarget(target: "Target4", buildTypes: [.testing]),
                    Scheme.BuildTarget(target: "Target5", buildTypes: []),
                    Scheme.BuildTarget(target: "Target6", buildTypes: [.testing, .analyzing]),
                ]
                try expect(scheme.name) == "temp2"
                try expect(Set(scheme.build.targets)) == Set(expectedTargets)
                try expect(scheme.build.preActions.first?.script) == "modified-name"
                try expect(scheme.build.preActions.first?.name) == "Before Build temp2"
                try expect(scheme.build.preActions.first?.settingsTarget) == "TargetFirstTarget"

                try expect(scheme.build.parallelizeBuild) == false
                try expect(scheme.build.buildImplicitDependencies) == false
                try expect(scheme.build.runPostActionsOnFailure) == true

                try expect(scheme.run?.storeKitConfiguration) == "Configuration.storekit"

                let expectedTest = Scheme.Test(
                    config: "debug",
                    gatherCoverageData: true,
                    disableMainThreadChecker: true,
                    targets: [
                        "TargetFirstTarget",
                        Scheme.Test.TestTarget(
                            targetReference: "Target2",
                            randomExecutionOrder: true,
                            parallelizable: true,
                            skippedTests: ["Test/testExample()"]
                        ),
                    ]
                )
                try expect(scheme.test) == expectedTest

                let expectedManagement = Scheme.Management(shared: false, orderHint: 8, isShown: nil)
                try expect(scheme.management) == expectedManagement
            }

            $0.it("parses copy files on install") {
                var targetSource = validTarget
                targetSource["onlyCopyFilesOnInstall"] = true
                let target = try Target(name: "Embed Frameworks", jsonDictionary: targetSource)
                try expect(target.onlyCopyFilesOnInstall) == true
            }

            $0.it("parses put resources before Sources Build Phase") {
                var targetSource = validTarget
                targetSource["putResourcesBeforeSourcesBuildPhase"] = true
                let target = try Target(name: "Embed Frameworks", jsonDictionary: targetSource)
                try expect(target.putResourcesBeforeSourcesBuildPhase) == true
            }

            $0.it("parses settings") {
                let project = try Project(path: fixturePath + "settings_test.yml")
                let buildSettings: BuildSettings = ["SETTING": "value"]
                let configSettings: [String: Settings] = ["config1": Settings(buildSettings: ["SETTING1": "value"])]
                let groups = ["preset1"]

                let preset1 = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
                let preset2 = Settings(buildSettings: [:], configSettings: configSettings, groups: [])
                let preset3 = Settings(buildSettings: buildSettings, configSettings: configSettings, groups: [])
                let preset4 = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
                let preset5 = Settings(buildSettings: buildSettings, configSettings: [:], groups: groups)
                let preset6 = Settings(buildSettings: buildSettings, configSettings: configSettings, groups: groups)
                let preset7 = Settings(buildSettings: buildSettings, configSettings: ["config1": Settings(buildSettings: buildSettings, groups: groups)])
                let preset8 = Settings(buildSettings: [:], configSettings: ["config1": Settings(configSettings: configSettings)])

                try expect(project.settingGroups.count) == 8
                try expect(project.settingGroups["preset1"]) == preset1
                try expect(project.settingGroups["preset2"]) == preset2
                try expect(project.settingGroups["preset3"]) == preset3
                try expect(project.settingGroups["preset4"]) == preset4
                try expect(project.settingGroups["preset5"]) == preset5
                try expect(project.settingGroups["preset6"]) == preset6
                try expect(project.settingGroups["preset7"]) == preset7
                try expect(project.settingGroups["preset8"]) == preset8
            }

            $0.it("parses run scripts") {
                var target = validTarget
                let scripts: [[String: Any]] = [
                    ["path": "script.sh"],
                    ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "runOnlyWhenInstalling": true],
                    ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "showEnvVars": false],
                    ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "basedOnDependencyAnalysis": false],
                    ["script": "shell script\nwith file lists", "name": "myscript", "inputFileLists": ["inputList.xcfilelist"], "outputFileLists": ["outputList.xcfilelist"], "shell": "bin/customshell", "runOnlyWhenInstalling": true],
                    ["script": "shell script\nwith file lists", "name": "myscript", "inputFileLists": ["inputList.xcfilelist"], "outputFileLists": ["outputList.xcfilelist"], "shell": "bin/customshell", "showEnvVars": false],
                    ["script": "shell script\nwith file lists", "name": "myscript", "inputFileLists": ["inputList.xcfilelist"], "outputFileLists": ["outputList.xcfilelist"], "shell": "bin/customshell", "basedOnDependencyAnalysis": false],
                ]
                target["preBuildScripts"] = scripts
                target["postCompileScripts"] = scripts
                target["postBuildScripts"] = scripts

                let expectedScripts = [
                    BuildScript(script: .path("script.sh")),
                    BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: true, showEnvVars: true, basedOnDependencyAnalysis: true),
                    BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: false, showEnvVars: false, basedOnDependencyAnalysis: true),
                    BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: false, showEnvVars: true, basedOnDependencyAnalysis: false),
                    BuildScript(script: .script("shell script\nwith file lists"), name: "myscript", inputFileLists: ["inputList.xcfilelist"], outputFileLists: ["outputList.xcfilelist"], shell: "bin/customshell", runOnlyWhenInstalling: true, showEnvVars: true, basedOnDependencyAnalysis: true),
                    BuildScript(script: .script("shell script\nwith file lists"), name: "myscript", inputFileLists: ["inputList.xcfilelist"], outputFileLists: ["outputList.xcfilelist"], shell: "bin/customshell", runOnlyWhenInstalling: false, showEnvVars: false, basedOnDependencyAnalysis: true),
                    BuildScript(script: .script("shell script\nwith file lists"), name: "myscript", inputFileLists: ["inputList.xcfilelist"], outputFileLists: ["outputList.xcfilelist"], shell: "bin/customshell", runOnlyWhenInstalling: false, showEnvVars: true, basedOnDependencyAnalysis: false),
                ]

                let parsedTarget = try Target(name: "test", jsonDictionary: target)
                try expect(parsedTarget.preBuildScripts) == expectedScripts
                try expect(parsedTarget.postCompileScripts) == expectedScripts
                try expect(parsedTarget.postBuildScripts) == expectedScripts
            }

            $0.it("parses build rules") {
                var target = validTarget
                let buildRules: [[String: Any]] = [
                    [
                        "name": "My Rule",
                        "script": "my script",
                        "filePattern": "*.swift",
                        "outputFiles": ["file1", "file2"],
                        "outputFilesCompilerFlags": ["-a", "-b"],
                    ],
                    [
                        "compilerSpec": "apple.tool",
                        "fileType": "sourcecode.swift",
                    ],
                ]
                target["buildRules"] = buildRules

                let expectedBuildRules = [
                    BuildRule(fileType: .pattern("*.swift"), action: .script("my script"), name: "My Rule", outputFiles: ["file1", "file2"], outputFilesCompilerFlags: ["-a", "-b"]),
                    BuildRule(fileType: .type("sourcecode.swift"), action: .compilerSpec("apple.tool")),
                ]

                let parsedTarget = try Target(name: "test", jsonDictionary: target)
                try expect(parsedTarget.buildRules) == expectedBuildRules
            }

            $0.it("parses options") {
                let options = SpecOptions(
                    carthageBuildPath: "../Carthage/Build",
                    carthageExecutablePath: "../bin/carthage",
                    createIntermediateGroups: true,
                    bundleIdPrefix: "com.test",
                    developmentLanguage: "ja",
                    deploymentTarget: DeploymentTarget(
                        iOS: "11.1",
                        tvOS: "10.0",
                        watchOS: "3.0",
                        macOS: "10.12.1"
                    ),
                    fileTypes: ["abc": FileType(
                        file: false,
                        buildPhase: .sources,
                        attributes: ["a1", "a2"],
                        resourceTags: ["r1", "r2"],
                        compilerFlags: ["c1", "c2"])],
                    findCarthageFrameworks: true,
                    preGenCommand: "swiftgen",
                    postGenCommand: "pod install",
                    schemePathPrefix: "../"
                )
                let expected = Project(name: "test", options: options)
                let dictionary: [String: Any] = ["options": [
                    "carthageBuildPath": "../Carthage/Build",
                    "carthageExecutablePath": "../bin/carthage",
                    "bundleIdPrefix": "com.test",
                    "createIntermediateGroups": true,
                    "developmentLanguage": "ja",
                    "deploymentTarget": ["iOS": 11.1, "tvOS": 10.0, "watchOS": "3", "macOS": "10.12.1"],
                    "findCarthageFrameworks": true,
                    "preGenCommand": "swiftgen",
                    "postGenCommand": "pod install",
                    "fileTypes": ["abc": [
                        "file": false,
                        "buildPhase": "sources",
                        "attributes": ["a1", "a2"],
                        "resourceTags": ["r1", "r2"],
                        "compilerFlags": ["c1", "c2"],
                        ]],
                    "schemePathPrefix": "../",
                ]]
                let parsedSpec = try getProjectSpec(dictionary)
                try expect(parsedSpec) == expected
            }

            $0.it("parses packages") {
                let project = Project(name: "spm", packages: [
                    "package1": .remote(url: "package.git", versionRequirement: .exact("1.2.2")),
                    "package2": .remote(url: "package.git", versionRequirement: .upToNextMajorVersion("1.2.2")),
                    "package3": .remote(url: "package.git", versionRequirement: .upToNextMinorVersion("1.2.2")),
                    "package4": .remote(url: "package.git", versionRequirement: .branch("master")),
                    "package5": .remote(url: "package.git", versionRequirement: .revision("x")),
                    "package6": .remote(url: "package.git", versionRequirement: .range(from: "1.2.0", to: "1.2.5")),
                    "package7": .remote(url: "package.git", versionRequirement: .exact("1.2.2")),
                    "package8": .remote(url: "package.git", versionRequirement: .upToNextMajorVersion("4.0.0-beta.5")),
                    "package9": .local(path: "package/package", group: nil, excludeFromProject: false),
                    "package10": .remote(url: "https://github.com/yonaskolb/XcodeGen", versionRequirement: .exact("1.2.2")),
                    "XcodeGen": .local(path: "../XcodeGen", group: nil, excludeFromProject: false),
                    "package11": .local(path: "../XcodeGen", group: "Packages/Feature", excludeFromProject: false),
                ], options: .init(localPackagesGroup: "MyPackages"))

                let dictionary: [String: Any] = [
                    "name": "spm",
                    "options": [
                        "localPackagesGroup": "MyPackages",
                    ],
                    "packages": [
                        "package1": ["url": "package.git", "exactVersion": "1.2.2"],
                        "package2": ["url": "package.git", "majorVersion": "1.2.2"],
                        "package3": ["url": "package.git", "minorVersion": "1.2.2"],
                        "package4": ["url": "package.git", "branch": "master"],
                        "package5": ["url": "package.git", "revision": "x"],
                        "package6": ["url": "package.git", "minVersion": "1.2.0", "maxVersion": "1.2.5"],
                        "package7": ["url": "package.git", "version": "1.2.2"],
                        "package8": ["url": "package.git", "majorVersion": "4.0.0-beta.5"],
                        "package9": ["path": "package/package"],
                        "package10": ["github": "yonaskolb/XcodeGen", "exactVersion": "1.2.2"],
                        "package11": ["path": "../XcodeGen", "group": "Packages/Feature"],
                    ],
                    "localPackages": ["../XcodeGen"],
                ]
                let parsedSpec = try getProjectSpec(dictionary)
                try expect(parsedSpec) == project
            }

            $0.it("parses old local package format") {
                let project = Project(name: "spm", packages: [
                    "XcodeGen": .local(path: "../XcodeGen", group: nil, excludeFromProject: false),
                    "Yams": .local(path: "Yams", group: nil, excludeFromProject: false),
                ], options: .init(localPackagesGroup: "MyPackages"))

                let dictionary: [String: Any] = [
                    "name": "spm",
                    "options": [
                        "localPackagesGroup": "MyPackages",
                    ],
                    "localPackages": ["../XcodeGen", "Yams"],
                ]
                let parsedSpec = try getProjectSpec(dictionary)
                try expect(parsedSpec) == project
            }

            $0.it("parses TargetScheme storeKitConfiguration as string") {
                var targetDictionary = validTarget
                targetDictionary["scheme"] = [
                    "storeKitConfiguration": "Configuration.storekit",
                ]

                let target = try Target(name: "test", jsonDictionary: targetDictionary)

                let scheme = TargetScheme(
                    storeKitConfiguration: "Configuration.storekit"
                )

                try expect(target.scheme) == scheme
            }

            $0.it("parses Scheme.Run storeKitConfiguration as string") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "targets": [:],
                    ],
                    "run": [
                        "config": "debug",
                        "storeKitConfiguration": "Configuration.storekit",
                    ],
                ]
                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)

                let runAction = Scheme.Run(
                    config: "debug",
                    storeKitConfiguration: "Configuration.storekit"
                )

                try expect(scheme.run) == runAction
            }

            $0.it("parses buildToolPlugins") {
                var target = validTarget
                let buildToolPlugins: [[String: Any]] = [
                    [
                        "plugin": "FirstPlugin",
                        "package": "FirstPackage"
                    ],
                    [
                        "plugin": "SecondPlugin",
                        "package": "SecondPackage"
                    ]
                ]
                target["buildToolPlugins"] = buildToolPlugins

                let expectedBuildToolPlugins = [
                    BuildToolPlugin(plugin: "FirstPlugin", package: "FirstPackage"),
                    BuildToolPlugin(plugin: "SecondPlugin", package: "SecondPackage")
                ]

                let parsedTarget = try Target(name: "test", jsonDictionary: target)
                try expect(parsedTarget.buildToolPlugins) == expectedBuildToolPlugins
            }
        }
    }

    func testPackagesVersion() {
        describe {
            let invalidPackages = [
                ["url": "package.git", "majorVersion": "master"],
                ["url": "package.git", "from": "develop"],
                ["url": "package.git", "minVersion": "feature/swift5.2", "maxVersion": "9.1.0"],
                ["url": "package.git", "minorVersion": "x.1.2"],
                ["url": "package.git", "exactVersion": "1.2.3.1"],
                ["url": "package.git", "version": "foo-bar"],
            ]

            $0.it("is an invalid package version") {
                for dictionary in invalidPackages {
                    try expect(expression: { _ = try SwiftPackage(jsonDictionary: dictionary) }).toThrow()
                }
            }
        }
    }

    func testDecoding() throws {
        describe {
            $0.it("decodes dots in dictionary keys") {
                let dictionary: [String: Any] = [
                    "test": [
                        "one.two": true,
                    ],
                ]

                let booleans: [String: Bool] = try dictionary.json(atKeyPath: "test")
                try expect(booleans) == ["one.two": true]
            }
        }
    }
}

@discardableResult
private func getProjectSpec(_ project: [String: Any], file: String = #file, line: Int = #line) throws -> Project {
    var projectDictionary: [String: Any] = ["name": "test"]
    for (key, value) in project {
        projectDictionary[key] = value
    }
    do {
        return try Project(jsonDictionary: projectDictionary)
    } catch {
        throw failure("\(error)", file: file, line: line)
    }
}

private func loadSpec(path: Path, variables: [String: String] = [:], file: String = #file, line: Int = #line) throws -> Project {
    do {
        let specLoader = SpecLoader(version: "1.1.0")
        return try specLoader.loadProject(path: path, variables: variables)
    } catch {
        throw failure("\(error)", file: file, line: line)
    }
}

private func expectSpecError(_ project: [String: Any], _ expectedError: SpecParsingError, file: String = #file, line: Int = #line) throws {
    try expectError(expectedError, file: file, line: line) {
        try getProjectSpec(project)
    }
}

private func expectTargetError(_ target: [String: Any], _ expectedError: SpecParsingError, file: String = #file, line: Int = #line) throws {
    try expectError(expectedError, file: file, line: line) {
        _ = try Target(name: "test", jsonDictionary: target)
    }
}

private func expectBreakpointError(_ breakpoint: [String: Any], _ expectedError: SpecParsingError, file: String = #file, line: Int = #line) throws {
    try expectError(expectedError, file: file, line: line) {
        _ = try Breakpoint(jsonDictionary: breakpoint)
    }
}
