import KituraNet

/// Main class for the Kitura-HTTP2 API.
public class HTTP2 {
    private static let factory = H2ConnectionUpgradeFactory()
    
    init() {
        let _ = HTTP2.factory.name
    }
}
