//
//  ExportFile.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The CSV export as a shareable file named `setctl-export.csv`.
struct ExportFile: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("setctl-export.csv")
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
