import Foundation
import AVFoundation
import CommonCrypto
import os.log

private let log = Logger(subsystem: "com.willsigmon.openmic", category: "AmazonPollyTTS")

/// Amazon Polly TTS engine with neural voices.
/// Uses AWS SigV4 signing for authentication.
/// Falls back to SystemTTS on failure.
@MainActor
final class AmazonPollyTTS: CloudTTSBase {
    private let accessKey: String
    private let secretKey: String
    private let region: String
    private var voiceId: String

    init(accessKey: String, secretKey: String, region: String = "us-east-1", voiceId: String = "Joanna") {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
        self.voiceId = voiceId
        super.init(log: log)
    }

    // MARK: - Configuration

    func setVoice(id: String) {
        self.voiceId = id
    }

    // MARK: - Synthesis

    override func synthesize(text: String) async throws -> Data {
        let host = "polly.\(region).amazonaws.com"
        let path = "/v1/speech"
        guard let url = URL(string: "https://\(host)\(path)") else {
            throw AmazonPollyError.synthesizeFailed
        }

        let body: [String: Any] = [
            "Text": text,
            "VoiceId": voiceId,
            "Engine": "neural",
            "OutputFormat": "mp3"
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // AWS SigV4 signing
        try signRequest(&request, host: host, path: path, body: bodyData)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AmazonPollyError.synthesizeFailed
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
                throw AmazonPollyError.invalidCredentials
            }
            if httpResponse.statusCode == 429 {
                throw AmazonPollyError.rateLimited
            }
            log.error("Amazon Polly HTTP \(httpResponse.statusCode, privacy: .public) (\(data.count, privacy: .public) bytes)")
            throw AmazonPollyError.synthesizeFailed
        }

        guard !data.isEmpty else {
            throw AmazonPollyError.emptyResponse
        }

        return data
    }

    // MARK: - AWS SigV4 Signing

    private func signRequest(_ request: inout URLRequest, host: String, path: String, body: Data) throws {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        let service = "polly"
        let payloadHash = sha256Hex(body)

        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        request.setValue(payloadHash, forHTTPHeaderField: "X-Amz-Content-Sha256")

        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date"
        let canonicalHeaders = [
            "content-type:application/json",
            "host:\(host)",
            "x-amz-content-sha256:\(payloadHash)",
            "x-amz-date:\(amzDate)"
        ].joined(separator: "\n") + "\n"

        let canonicalRequest = [
            "POST",
            path,
            "",
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        guard let canonicalRequestData = canonicalRequest.data(using: .utf8) else {
            throw AmazonPollyError.synthesizeFailed
        }

        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            sha256Hex(canonicalRequestData)
        ].joined(separator: "\n")

        guard
            let secretKeyData = "AWS4\(secretKey)".data(using: .utf8),
            let dateStampData = dateStamp.data(using: .utf8),
            let regionData = region.data(using: .utf8),
            let serviceData = service.data(using: .utf8),
            let aws4RequestData = "aws4_request".data(using: .utf8),
            let stringToSignData = stringToSign.data(using: .utf8)
        else {
            throw AmazonPollyError.synthesizeFailed
        }

        let kDate = hmacSHA256(key: secretKeyData, data: dateStampData)
        let kRegion = hmacSHA256(key: kDate, data: regionData)
        let kService = hmacSHA256(key: kRegion, data: serviceData)
        let kSigning = hmacSHA256(key: kService, data: aws4RequestData)

        let signature = hmacSHA256(key: kSigning, data: stringToSignData)
            .map { String(format: "%02x", $0) }
            .joined()

        let authorization = "AWS4-HMAC-SHA256 Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    private func sha256Hex(_ data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func hmacSHA256(key: Data, data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        key.withUnsafeBytes { keyPtr in
            data.withUnsafeBytes { dataPtr in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                        keyPtr.baseAddress, key.count,
                        dataPtr.baseAddress, data.count,
                        &hash)
            }
        }
        return Data(hash)
    }
}
