
internal struct WeakSet {
    
    private var contents: [Int: [Entry]] = [:]
    
    init(_ objects: WithID...) {
        self.init(objects)
    }
    
    init(_ objects: [WithID]) {
        for object in objects {
            self.insert(object)
        }
    }
    
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
    
    mutating func remove(removeElement: WithID) {
        let entriesAtHash = validEntriesAtHash(removeElement.id)
        let entriesMinusElement = entriesAtHash.filter { $0.element?.id != removeElement.id }
        if entriesMinusElement.isEmpty {
            self.contents[removeElement.id] = nil
        } else {
            self.contents[removeElement.id] = entriesMinusElement
        }
    }
    
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
        
        return anyGenerator {
            if let element = entryGenerator?.next()?.element {
                return element
            } else {
                entryGenerator = contentsGenerator.next()?.generate()
                return entryGenerator?.next()?.element
            }
        }
    }
}
