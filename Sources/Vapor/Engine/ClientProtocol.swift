import HTTP
import Transport
import URI
import TLS

/// types conforming to this protocol can be 
/// set as the Droplet's `.client`
public protocol ClientProtocol: Responder {
    init(
        hostname: String,
        port: Port,
        _ securityLayer: SecurityLayer
    ) throws
}

// MARK: Convenience

extension ClientProtocol {
    /// Creates a new client from the information in the 
    /// Request URI and uses it to respond to the request.
    public static func respond(
        to req: Request,
        _ s: SecurityLayer? = nil
    ) throws -> Response {
        // use security layer from input or
        // determine based on req uri scheme
        let securityLayer = try s ??
            ((req.uri.scheme ==  "https")
                ? .tls(try EngineClient.defaultTLSContext())
                : .none)

        let client = try Self.init(
            hostname: req.uri.hostname,
            port: req.uri.port ?? 80,
            securityLayer
        )

        return try client.respond(to: req)
    }

    /// Creates a new client and calls `.respond()`
    /// using the request method and uri provided.
    public static func request(
        _ method: Method,
        _ uri: String,
        query: [String: NodeRepresentable] = [:],
        _ headers: [HeaderKey: String] = [:],
        _ body: BodyRepresentable? = nil
    ) throws  -> Response {
        var uri = try URI(uri)

        var q: [String: CustomStringConvertible] = [:]
        try query.forEach { key, value in
            q[key] = try value.makeNode(in: nil).string ?? ""
        }
        uri.append(query: q)

        let req = Request(method: method, uri: uri)
        req.headers = headers


        if let body = body {
            req.body = body.makeBody()
        }
        return try respond(to: req)
    }
}

// MARK: TLS

private var _defaultTLSClientContext: () throws -> (TLS.Context) = {
    return try Context(.client)
}

extension ClientProtocol {
    public static var defaultTLSContext: () throws -> (TLS.Context) {
        get {
            return _defaultTLSClientContext
        }
        set {
            _defaultTLSClientContext = newValue
        }

    }
}
