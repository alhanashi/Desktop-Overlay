import Foundation

/// Fixed-capacity circular buffer. Used to keep only the last N metric samples
/// for the sparklines (spec §18) — no long history is retained.
struct RingBuffer<Element> {
    private var storage: [Element?]
    private var writeIndex = 0
    private(set) var count = 0
    let capacity: Int

    init(capacity: Int) {
        precondition(capacity > 0, "RingBuffer capacity must be > 0")
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    var isFull: Bool { count == capacity }

    mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        count = Swift.min(count + 1, capacity)
    }

    mutating func removeAll() {
        for i in storage.indices { storage[i] = nil }
        writeIndex = 0
        count = 0
    }

    /// Elements ordered oldest → newest.
    var values: [Element] {
        guard count > 0 else { return [] }
        let start = isFull ? writeIndex : 0
        var result = [Element]()
        result.reserveCapacity(count)
        for offset in 0..<count {
            let index = (start + offset) % capacity
            if let value = storage[index] {
                result.append(value)
            }
        }
        return result
    }
}
