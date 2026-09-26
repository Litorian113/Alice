import AVFoundation
import SwiftUI
import VisionKit

struct PairingSheet: View {
    @EnvironmentObject private var store: AliceSessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var cameraAllowed = false
    @State private var cameraDenied = false
    @State private var scannerError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Eyebrow(text: "Alice + Bob")
                    Spacer()
                    Button("Done") { dismiss() }.frame(minHeight: 44)
                }
                AliceMascot(faceOnly: true).frame(width: 96, height: 80)
                Text(store.pairingCandidate == nil ? "Meet your other half." : "Connect this workspace?")
                    .font(.plex(28, weight: .semibold)).multilineTextAlignment(.center)
                if let candidate = store.pairingCandidate {
                    VStack(spacing: 8) {
                        Image(systemName: "laptopcomputer").font(.system(size: 34)).foregroundStyle(Color.aliceAccent)
                        Text(candidate.relayURL.host ?? "Bob").font(.plex(18, weight: .medium))
                        Text("Session \(candidate.sessionId)").font(.plex(13)).foregroundStyle(Color.aliceSecondary)
                    }.padding(24).frame(maxWidth: .infinity).aliceSurface()
                    PrimaryButton(title: "Connect to Bob", icon: "link") { store.confirmPairing() }
                    Button("Scan another code") { store.pairingCandidate = nil }
                } else {
                    Text("Ask Bob to “pair my phone” in Companion mode on your computer. Scan the QR code he shows you.")
                        .font(.plex(15)).foregroundStyle(Color.aliceSecondary).multilineTextAlignment(.center)
                    if cameraAllowed && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                        QRScanner { text in
                            guard let url = URL(string: text) else { return }
                            store.handleURL(url)
                        } onError: { scannerError = $0 }
                        .frame(height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.aliceAccent.opacity(0.4), lineWidth: 2))
                        .accessibilityLabel("Scan Bob's pairing QR code")
                    } else {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 68))
                            .foregroundStyle(Color.aliceAccent).padding(32)
                        Text(cameraDenied ? "Allow camera access in Settings to scan Bob's code." : "You can also scan the code with the iPhone Camera app and open Alice.")
                            .font(.plex(14)).multilineTextAlignment(.center)
                        if cameraDenied {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                    }
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first, let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                        store.handleURL(url)
                    }.labelStyle(.titleAndIcon)
                    Text("Or paste Bob's pairing link.").font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                }
                if let error = store.errorMessage ?? scannerError {
                    Text(error).font(.plex(14)).foregroundStyle(Color.aliceError).multilineTextAlignment(.center)
                }
            }.padding(24)
        }
        .background(Color.aliceBackground)
        .task {
            guard store.pairingCandidate == nil else { return }
            cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            cameraDenied = !cameraAllowed
        }
    }
}

private struct QRScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    var onError: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode, onError: onError) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !scanner.isScanning else { return }
        do { try scanner.startScanning() }
        catch { DispatchQueue.main.async { onError("The camera isn't ready. Try the Camera app or paste the link.") } }
    }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        let onError: (String) -> Void
        private var previous = ""
        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCode = onCode; self.onError = onError
        }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let text = barcode.payloadStringValue, text != previous {
                    previous = text
                    onCode(text)
                }
            }
        }
        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            onError("Scanning is unavailable. Use the Camera app or paste Bob's pairing link.")
        }
    }
}
