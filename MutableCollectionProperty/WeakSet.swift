
/// Weak, unordered collection of objects by Adam Preble.
internal struct WeakSet {
    
    /// Maps Element hashValues to arrays of Entry objects.
    /// Invalid Entry instances are culled as a side effect of add() and remove()
    /// when they touch an object with the same hashValue.
    private var contents: [Int: [Entry]] = [:]
    
    init(_ objects: WithID...) {
        self.init(objects)
    }
    
    init(_ objects: [WithID]) {
        for object in objects {
            self.insert(object)
        }
    }
    
    /// Add an element to the set.
    mutating func insert(newElement: WithID) {
        var entriesAtHash = validEntriesAtHash(newElement.id)
        for entry in entriesAtHash {
            if let existingElement = entry.element {
                if existingElement.id == newElement.id {
                    return
                }
            }
        }
        let entry = Entry(element: newElement)
        entriesAtHash.append(entry)
        self.contents[newElement.id] = entriesAtHash
    }
    
    /// Remove an element from the set.
    mutating func remove(removeElement: WithID) {
        let entriesAtHash = validEntriesAtHash(removeElement.id)
        let entriesMinusElement = entriesAtHash.filter { $0.element?.id != removeElement.id }
        if entriesMinusElement.isEmpty {
            self.contents[removeElement.id] = nil
        } else {
            self.contents[removeElement.id] = entriesMinusElement
        }
    }
    
    // Does the set contain this element?
    func contains(element: WithID) -> Bool {
        let entriesAtHash = validEntriesAtHash(element.id)
        for entry in entriesAtHash {
            if entry.element?.id == element.id {
                return true
            }
        }
        return false
    }
    
    private func validEntriesAtHash(hashValue: Int) -> [Entry] {
        if let entries = self.contents[hashValue] {
            return entries.filter { $0.element != nil }
        } else {
            return []
        }
    }
}

private struct Entry {
    weak var element: WithID?
}


// MARK: SequenceType

extension WeakSet : SequenceType {
    typealias Generator = AnyGenerator<WithID>
    
    func generate() -> Generator {
        var contentsGenerator = self.contents.values.generate()
        var entryGenerator = contentsGenerator.next()?.generate()
        
        return AnyGenerator {
            if let element = entryGenerator?.next()?.element {
                return element
            } else {
                entryGenerator = contentsGenerator.next()?.generate()
                return entryGenerator?.next()?.element
            }
        }
    }
}
