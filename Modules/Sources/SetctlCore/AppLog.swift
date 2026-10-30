//
//  AppLog.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

import OSLog

/// The app's loggers, grouped by area. Filter by subsystem and category in Console.app.
public enum AppLog {
    private static let subsystem = "com.stay.Setctl"

    public static let data = Logger(subsystem: subsystem, category: "data")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
}
