import Foundation
import zlib

/// Read-only inspection of Readium LCP for PDF packages.
/// Does **not** decrypt content or extract cryptographic secrets.
enum LCPInspector {
    static func inspect(url: URL) throws -> LCPLicenseSummary {
        let archive = try ZipReader(url: url)
        let manifestData = try archive.data(for: "manifest.json")
        let licenseData = try archive.data(for: "license.lcpl")

        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any] ?? [:]
        let license = try JSONSerialization.jsonObject(with: licenseData) as? [String: Any] ?? [:]

        let metadata = manifest["metadata"] as? [String: Any]
        let title = metadata?["title"] as? String
        let pageCount = metadata?["numberOfPages"] as? Int

        let readingOrder = manifest["readingOrder"] as? [[String: Any]] ?? []
        let encrypted = readingOrder.contains { entry in
            let props = entry["properties"] as? [String: Any]
            let enc = props?["encrypted"] as? [String: Any]
            return enc != nil
        }

        let encryption = license["encryption"] as? [String: Any]
        let rights = license["rights"] as? [String: Any]

        let end = rights?["end"] as? String
        var status = "LCP-protected publication"
        if encrypted {
            status = "Encrypted with Readium LCP. Official macOS decryption requires EDRLab’s private R2LCPClient (not bundled)."
        }
        if let end {
            status += " License ends: \(end)."
        }

        return LCPLicenseSummary(
            provider: license["provider"] as? String,
            issued: license["issued"] as? String,
            profile: encryption?["profile"] as? String,
            printAllowance: rights?["print"] as? Int,
            copyAllowance: rights?["copy"] as? Int,
            start: rights?["start"] as? String,
            end: end,
            encrypted: encrypted,
            pageCount: pageCount,
            title: title,
            statusMessage: status
        )
    }

    static func extractCover(from url: URL) throws -> Data? {
        let archive = try ZipReader(url: url)
        if let jpg = try? archive.data(for: "cover.jpg") { return jpg }
        if let jpeg = try? archive.data(for: "cover.jpeg") { return jpeg }
        if let png = try? archive.data(for: "cover.png") { return png }
        return nil
    }
}

/// Minimal ZIP reader for uncompressed / deflated local file headers.
/// Sufficient for Readium LCPDF packages (manifest, license, cover).
final class ZipReader {
    private let data: Data

    init(url: URL) throws {
        data = try Data(contentsOf: url, options: [.mappedIfSafe])
    }

    func data(for path: String) throws -> Data {
        var offset = 0
        let count = data.count
        while offset + 30 <= count {
            let sig = readUInt32(at: offset)
            if sig != 0x04034b50 { break }
            let compression = Int(readUInt16(at: offset + 8))
            let compSize = Int(readUInt32(at: offset + 18))
            let uncompSize = Int(readUInt32(at: offset + 22))
            let nameLen = Int(readUInt16(at: offset + 26))
            let extraLen = Int(readUInt16(at: offset + 28))
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLen
            guard nameEnd <= count else { throw ZipError.corrupt }
            let name = String(data: data.subdata(in: nameStart..<nameEnd), encoding: .utf8) ?? ""
            let dataStart = nameEnd + extraLen
            let dataEnd = dataStart + compSize
            guard dataEnd <= count else { throw ZipError.corrupt }

            if name == path || name.hasSuffix("/" + path) {
                let payload = data.subdata(in: dataStart..<dataEnd)
                if compression == 0 {
                    return payload
                }
                if compression == 8 {
                    return try inflate(payload, expectedSize: uncompSize)
                }
                throw ZipError.unsupportedCompression
            }
            offset = dataEnd
        }
        throw ZipError.entryNotFound(path)
    }

    private func readUInt16(at offset: Int) -> UInt16 {
        data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
    }

    private func readUInt32(at offset: Int) -> UInt32 {
        data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
    }

    private func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        var stream = z_stream()
        var status = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw ZipError.inflateFailed }
        defer { inflateEnd(&stream) }

        var inputCopy = [UInt8](input)
        var output = [UInt8](repeating: 0, count: max(expectedSize, 1024))
        var outOffset = 0

        inputCopy.withUnsafeMutableBufferPointer { inBuf in
            stream.next_in = inBuf.baseAddress
            stream.avail_in = uInt(inBuf.count)

            repeat {
                if outOffset >= output.count {
                    output.append(contentsOf: [UInt8](repeating: 0, count: max(output.count, 32_768)))
                }
                let available = output.count - outOffset
                output.withUnsafeMutableBufferPointer { outBuf in
                    stream.next_out = outBuf.baseAddress?.advanced(by: outOffset)
                    stream.avail_out = uInt(available)
                    status = inflate(&stream, Z_FINISH)
                }
                outOffset = Int(stream.total_out)
            } while status == Z_OK || status == Z_BUF_ERROR
        }

        guard status == Z_STREAM_END else { throw ZipError.inflateFailed }
        return Data(output.prefix(outOffset))
    }
}

enum ZipError: LocalizedError {
    case corrupt
    case entryNotFound(String)
    case unsupportedCompression
    case inflateFailed

    var errorDescription: String? {
        switch self {
        case .corrupt: "Corrupt ZIP archive."
        case .entryNotFound(let name): "Missing entry: \(name)"
        case .unsupportedCompression: "Unsupported ZIP compression."
        case .inflateFailed: "Failed to decompress ZIP entry."
        }
    }
}
