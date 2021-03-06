//
//  ObjectivecVariablesParser.swift
//  Natrium
//
//  Created by Bas van Kuijck on 04/07/2018.
//

import Foundation
import Yaml
import Francium

class ObjectivecVariablesParser: Parser {

    let natrium: Natrium
    var isRequired: Bool {
        return true
    }

    var yamlKey: String {
        return "variables"
    }

    required init(natrium: Natrium) {
        self.natrium = natrium
    }

    private let preservedVariableNames = [ "environment", "configuration" ]

    private var templateH: String {
        return """
        /// NatriumConfig.h
        /// Autogenerated by natrium
        ///
        /// - see: https://github.com/e-sites/Natrium

        #import <Foundation/Foundation.h>

        typedef NS_ENUM(NSInteger, EnvironmentType) {
        {%environments%}
        };

        typedef NS_ENUM(NSInteger, ConfigurationType) {
        {%configurations%}
        };

        @interface NatriumConfig: NSObject

        + (EnvironmentType)environment;
        + (ConfigurationType)configuration;
        {%customvariables%}

        @end

        """
    }

    private var templateM: String {
        return """
        /// NatriumConfig.m
        /// Autogenerated by natrium
        ///
        /// - see: https://github.com/e-sites/Natrium

        #import "NatriumConfig.h"

        @implementation NatriumConfig

        + (EnvironmentType)environment {
            return EnvironmentType{%environment%};
        }

        + (ConfigurationType)configuration {
            return ConfigurationType{%configuration%};
        }

        {%customvariables%}
        
        @end

        """
    }

    func parse(_ yaml: [NatriumKey: Yaml]) { // swiftlint:disable:this function_body_length
        let environments = natrium.environments.map {
            return "    EnvironmentType\($0)"
        }.joined(separator: ",\n")

        let configurations = natrium.configurations.map {
            return "    ConfigurationType\($0)"
        }.joined(separator: ",\n")

        var customVariables: String = ""
        func parseCustomVariables(isParsingHeader: Bool = true) {
            customVariables = yaml.map { key, value in
                if preservedVariableNames.contains(key.string) {
                    Logger.fatalError("\(key.string) is a reserved variable name")
                }
                let type: String
                var stringValue = value.stringValue
                switch value {
                case .int:
                    type = "NSInteger"
                case .double:
                    type = "CGFloat"
                case .bool:
                    type = "BOOL"
                    if stringValue == "true" {
                        stringValue = "YES"
                    } else {
                        stringValue = "NO"
                    }
                case .null:
                    type = "NSObject *"
                    stringValue = "NULL"
                default:
                    type = "NSString *"
                    stringValue = "@\"\(value.stringValue)\""
                }
                if isParsingHeader {
                    return "+ (\(type))\(key.string);"
                }
                return """
                + (\(type))\(key.string) {
                    return \(stringValue);
                }

                """
            }.joined(separator: "\n")
        }

        parseCustomVariables()

        var contents = templateH
        var array: [(String, String)] = [
            ("environments", environments),
            ("environment", natrium.environment),
            ("configurations", configurations),
            ("configuration", natrium.configuration),
            ("customvariables", customVariables)
        ]

        for object in array {
            contents = contents.replacingOccurrences(of: "{%\(object.0)%}", with: object.1)
        }

        let currentDirectory = FileManager.default.currentDirectoryPath
        var filePath = "\(currentDirectory)/Objc/NatriumConfig.h"
        do {
            var file = File(path: filePath)
            if file.isExisting {
                file.chmod(0o7777)
            }
            try file.write(string: contents)

            parseCustomVariables(isParsingHeader: false)

            contents = templateM
            array = [
                ("environments", environments),
                ("environment", natrium.environment),
                ("configurations", configurations),
                ("configuration", natrium.configuration),
                ("customvariables", customVariables)
            ]

            for object in array {
                contents = contents.replacingOccurrences(of: "{%\(object.0)%}", with: object.1)
            }

            filePath = "\(currentDirectory)/Objc/NatriumConfig.m"
            file = File(path: filePath)
            if file.isExisting {
                file.chmod(0o7777)
            }
            try? file.write(string: contents)
        } catch { }
    }
}
