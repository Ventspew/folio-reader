import Foundation
import zlib

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
                    return try inflateRaw(payload, expectedSize: uncompSize)
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

    private func inflateRaw(_ input: Data, expectedSize: Int) throws -> Data {
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
                    status = zlib.inflate(&stream, Z_FINISH)
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
