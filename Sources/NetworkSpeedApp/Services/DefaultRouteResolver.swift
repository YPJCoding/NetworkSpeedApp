enum NetworkInterfacePolicy {
    static func isPhysical(_ name: String) -> Bool {
        name.hasPrefix("en")
    }
}
