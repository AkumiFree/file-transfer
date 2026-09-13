// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FileTransfer-iOS",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FileTransferCore", targets: ["FileTransferCore"])
    ],
    targets: [
        .target(
            name: "FileTransferCore",
            path: "FileTransfer",
            exclude: [
                "FileTransferApp.swift",
                "Views",
                "Resources",
                "Services/AppState.swift"
            ],
        sources: [
                "Models/AppModels.swift",
                "Services/APIClient.swift",
                "Services/EndpointResolver.swift",
                "Services/KeychainStore.swift",
                "Services/LocalFileStore.swift",
                "Services/TransferService.swift",
                "Services/WebSocketClient.swift"
            ]
        ),
        .testTarget(
            name: "FileTransferCoreTests",
            dependencies: ["FileTransferCore"],
            path: "FileTransferTests"
        )
    ]
)
