// RUN: %empty-directory(%t)
// RUN: split-file %s %t

/// Build lib defining SPIs
// RUN: %target-swift-frontend -emit-module %t/Exported.swift \
// RUN:   -module-name Exported -swift-version 5 \
// RUN:   -enable-library-evolution \
// RUN:   -emit-module-path %t/Exported.swiftmodule \
// RUN:   -emit-module-interface-path %t/Exported.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/Exported.private.swiftinterface
// RUN: %target-swift-typecheck-module-from-interface(%t/Exported.swiftinterface)
// RUN: %target-swift-typecheck-module-from-interface(%t/Exported.private.swiftinterface) -module-name Exported

/// Build lib reexporting SPIs
// RUN: %target-swift-frontend -emit-module %t/Exporter.swift \
// RUN:   -module-name Exporter -swift-version 5 -I %t \
// RUN:   -enable-library-evolution \
// RUN:   -emit-module-path %t/Exporter.swiftmodule \
// RUN:   -emit-module-interface-path %t/Exporter.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/Exporter.private.swiftinterface
// RUN: %target-swift-typecheck-module-from-interface(%t/Exporter.swiftinterface) -I %t
// RUN: %target-swift-typecheck-module-from-interface(%t/Exporter.private.swiftinterface) -module-name Exporter -I %t

/// Build lib not reexporting SPIs (a normal import)
// RUN: %target-swift-frontend -emit-module %t/NonExporter.swift \
// RUN:   -module-name NonExporter -swift-version 5 -I %t \
// RUN:   -enable-library-evolution \
// RUN:   -emit-module-path %t/NonExporter.swiftmodule \
// RUN:   -emit-module-interface-path %t/NonExporter.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/NonExporter.private.swiftinterface
// RUN: %target-swift-typecheck-module-from-interface(%t/NonExporter.swiftinterface) -I %t
// RUN: %target-swift-typecheck-module-from-interface(%t/NonExporter.private.swiftinterface) -module-name NonExporter -I %t

/// Build client of transitive SPIs and its swiftinterfaces
// RUN: %target-swift-frontend -emit-module %t/ClientLib.swift \
// RUN:   -module-name ClientLib -swift-version 5 -I %t \
// RUN:   -enable-library-evolution \
// RUN:   -emit-module-path %t/ClientLib.swiftmodule \
// RUN:   -emit-module-interface-path %t/ClientLib.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/ClientLib.private.swiftinterface
// RUN: %target-swift-typecheck-module-from-interface(%t/ClientLib.swiftinterface) -I %t
// RUN: %target-swift-typecheck-module-from-interface(%t/ClientLib.private.swiftinterface) -module-name ClientLib -I %t

/// Test diagnostics of a multifile client
// RUN: %target-swift-frontend -typecheck \
// RUN:   %t/Client_FileA.swift %t/Client_FileB.swift\
// RUN:   -swift-version 5 -I %t -verify

/// Test that SPIs don't leak when not reexported
// RUN: %target-swift-frontend -typecheck \
// RUN:   %t/NonExporterClient.swift \
// RUN:   -swift-version 5 -I %t -verify

/// Test diagnostics against private swiftinterfaces
// RUN: rm %t/Exported.swiftmodule %t/Exporter.swiftmodule
// RUN: %target-swift-frontend -typecheck \
// RUN:   %t/Client_FileA.swift %t/Client_FileB.swift\
// RUN:   -swift-version 5 -I %t -verify

/// Test diagnostics against public swiftinterfaces
// RUN: rm %t/Exported.private.swiftinterface %t/Exporter.private.swiftinterface
// RUN: %target-swift-frontend -typecheck \
// RUN:   %t/PublicClient.swift \
// RUN:   -swift-version 5 -I %t -verify


//--- Exported.swift

public func exportedPublicFunc() {}

@_spi(X) public func exportedSpiFunc() {}

@_spi(X) public struct ExportedSpiType {}

//--- Exporter.swift

@_exported import Exported

@_spi(X) public func exporterSpiFunc() {}

//--- NonExporter.swift

@_spi(X) import Exported

@_spi(X) public func exporterSpiFunc() {}

//--- ClientLib.swift

@_spi(X) import Exporter

public func clientA() {
    exportedPublicFunc()
    exportedSpiFunc()
    exporterSpiFunc()
}

@_spi(X) public func spiUseExportedSpiType(_ a: ExportedSpiType) {}

//--- Client_FileA.swift

@_spi(X) import Exporter

public func clientA() {
    exportedPublicFunc()
    exportedSpiFunc()
    exporterSpiFunc()
}

@inlinable
public func inlinableClient() {
    exportedPublicFunc()
    exportedSpiFunc() // expected-error {{global function 'exportedSpiFunc()' cannot be used in an '@inlinable' function because it is an SPI imported from 'Exported'}}
    exporterSpiFunc() // expected-error {{global function 'exporterSpiFunc()' cannot be used in an '@inlinable' function because it is an SPI imported from 'Exporter'}}
}

@_spi(X) public func spiUseExportedSpiType(_ a: ExportedSpiType) {}

public func publicUseExportedSpiType(_ a: ExportedSpiType) {} // expected-error {{cannot use struct 'ExportedSpiType' here; it is an SPI imported from 'Exported'}}

//--- Client_FileB.swift

import Exporter

public func clientB() {
    exportedPublicFunc()
    exportedSpiFunc() // expected-error {{cannot find 'exportedSpiFunc' in scope}}
    exporterSpiFunc() // expected-error {{cannot find 'exporterSpiFunc' in scope}}
}

//--- NonExporterClient.swift

@_spi(X) import NonExporter

public func client() {
    exportedPublicFunc() // expected-error {{cannot find 'exportedPublicFunc' in scope}}
    exportedSpiFunc() // expected-error {{cannot find 'exportedSpiFunc' in scope}}
    exporterSpiFunc()
}

//--- PublicClient.swift

@_spi(X) import Exporter // expected-warning {{'@_spi' import of 'Exporter' will not include any SPI symbols}}

public func client() {
    exportedPublicFunc()
    exportedSpiFunc() // expected-error {{cannot find 'exportedSpiFunc' in scope}}
    exporterSpiFunc() // expected-error {{cannot find 'exporterSpiFunc' in scope}}
}
