
internal struct WeakSet<T: WithID> {
    typealias Element = T
    
    private var contents: [Int: [Entry<Element>]] = [:]
    
    init(_ objects: T...) {
        self.init(objects)
    }
    
    init(_ objects: [T]) {
        for object in objects {
            self.insert(object)
        }
    }
    
    mutating func insert(newElement: Element) {
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
    
    mutating func remove(removeElement: Element) {
        let entriesAtHash = validEntriesAtHash(removeElement.id)
        let entriesMinusElement = entriesAtHash.filter { $0.element?.id != removeElement.id }
        if entriesMinusElement.isEmpty {
            self.contents[removeElement.id] = nil
        } else {
            self.contents[removeElement.id] = entriesMinusElement
        }
    }
    
    func contains(element: Element) -> Bool {
        let entriesAtHash = validEntriesAtHash(element.id)
        for entry in entriesAtHash {
            if entry.element?.id == element.id {
                return true
            }
        }
        return false
    }
    
    private func validEntriesAtHash(hashValue: Int) -> [Entry<Element>] {
        if let entries = self.contents[hashValue] {
            return entries.filter { $0.element != nil }
        } else {
            return []
        }
    }
}

private struct Entry<T: WithID> {
    typealias Element = T
    weak var _element: AnyObject?
    var element: T? {
        get {
            return self._element as? T
        }
        set {
            self._element = newValue as? AnyObject
        }
    }
    
    init(element: T) {
        self._element = element as? AnyObject
    }
}


// MARK: SequenceType

extension WeakSet : SequenceType {
    typealias Generator = AnyGenerator<T>
    
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
