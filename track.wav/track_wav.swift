//
//  track_wav.swift
//  track.wav
//
//  Created by jonny on 2025-12-31.
//

import Foundation
import ExtensionFoundation

/// The AppExtensionConfiguration that will be provided by this extension.
/// This is typically defined by the extension host in a framework.
struct ExampleConfiguration<E:ExampleExtension>: AppExtensionConfiguration {
    
    let appExtension: E
    
    init(_ appExtension: E) {
        self.appExtension = appExtension
    }
    
    /// Determine whether to accept the XPC connection from the host.
    func accept(connection: NSXPCConnection) -> Bool {
        // TODO: Configure the XPC connection and return true
        return false
    }
}

/// The AppExtension protocol to which this extension will conform.
/// This is typically defined by the extension host in a framework.
protocol ExampleExtension : AppExtension { }

extension ExampleExtension {
    var configuration: ExampleConfiguration<some ExampleExtension> {
        // Return your extension's configuration upon request.
        return ExampleConfiguration(self)
    }
}

@main
class track_wav: ExampleExtension {
    required init() {
        // Initialize your extension here.
    }
}
