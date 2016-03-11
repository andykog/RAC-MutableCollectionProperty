import Foundation
import ReactiveCocoa
import enum Result.NoError

internal protocol MutableCollectionSectionProtocol {
    func _getSubsection(atIndex _: Int) throws -> MutableCollectionSectionProtocol
    func _getItem<Z>(atIndexPath _: [Int]) throws -> Z
    func _removeItem<Z>(atIndexPath _: [Int]) throws -> Z
    mutating func _insert<Z>(_: Z, atIndexPath _: [Int]) throws
    var count: Int { get }
}

public enum MutableCollectionSectionError: ErrorType {
    case CantGetChild(type: String)
    case CantCastValue(type: String, targetType: String)
    case CantInsertElementOfType(elementType: String, sectionType: String)
    
    var description: String {
        switch self {
        case .CantGetChild(type: let type):
            return "Can't get child of an element of type \(type)"
        case .CantCastValue(type: let type, targetType: let targetType):
            return "Cannot cast value of type \(type) to \(targetType)"
        case .CantInsertElementOfType(elementType: let elementType, sectionType: let sectionType):
            return "Attempt to inset element of type \(elementType) in section of type \(sectionType)"
            
        }
    }
}

internal protocol WithID {
    var id: Int { get }
}

public class MutableCollectionProperty<T>: PropertyType, MutableCollectionSectionProtocol, WithID {
    
    public let id: Int
    
    init (_ items: [T]) {
        self._items = items
        self.id = Int(arc4random_uniform(6) + 1)
        self._lock.name = "org.reactivecocoa.ReactiveCocoa.MutableCollectionProperty"
        (self.producer, self._valueObserver) = SignalProducer<Value, NoError>.buffer(1)
        (self.signal, self._valueObserverSignal) = Signal<Value, NoError>.pipe()
        (self.flatChanges, self._flatChangesObserver) = SignalProducer<FlatMutableCollectionChange<Value.Element>, NoError>.buffer(1)
        (self.flatChangesSignal, self._flatChangesObserverSignal) = Signal<FlatMutableCollectionChange<Value.Element>, NoError>.pipe()
        (self.changes, self._changesObserver) = SignalProducer.buffer(1)
        (self.changesSignal, self._changesObserverSignal) = Signal.pipe()
    }
    
    deinit {
        self._valueObserver.sendCompleted()
        self._valueObserverSignal.sendCompleted()
        self._flatChangesObserver.sendCompleted()
        self._flatChangesObserverSignal.sendCompleted()
        self._changesObserver.sendCompleted()
        self._changesObserverSignal.sendCompleted()
    }
    
    // MARK: - Private attributes
    
    private var _items: [T]
    private let _valueObserver: Signal<Value, NoError>.Observer
    private let _valueObserverSignal: Signal<Value, NoError>.Observer
    private let _flatChangesObserver: Signal<FlatMutableCollectionChange<Value.Element>, NoError>.Observer
    private let _flatChangesObserverSignal: Signal<FlatMutableCollectionChange<Value.Element>, NoError>.Observer
    private let _changesObserver: Signal<MutableCollectionChange, NoError>.Observer
    private let _changesObserverSignal: Signal<MutableCollectionChange, NoError>.Observer
    private let _lock = NSRecursiveLock()
//    private var _parents = WeakSet<MutableCollectionProperty<MutableCollectionProperty<T>>>()
    
    
    // MARK: - Public Attributes
    
    public var producer: SignalProducer<Value, NoError>
    public var signal: Signal<Value, NoError>
    public var flatChanges: SignalProducer<FlatMutableCollectionChange<Value.Element>, NoError>
    public var flatChangesSignal: Signal<FlatMutableCollectionChange<Value.Element>, NoError>
    public var changes: SignalProducer<MutableCollectionChange, NoError>
    public var changesSignal: Signal<MutableCollectionChange, NoError>
    
    public var value: Value {
        get {
            return self._items
        }
        set {
            let diffResult = self.value.diff(newValue)
            self._items = newValue
            self._valueObserver.sendNext(newValue)
            self._dispatchFlatChange(.Composite(diffResult))
        }
    }
    
    public var items: [T] {
        return self._items
    }
    
    public var count: Int {
        return self._items.count
    }
    
    public typealias Value = [T]
    
    
    // MARK: - Private methods
    
    private func _dispatchDeepChange(e: MutableCollectionChange) {
        self._changesObserver.sendNext(e)
        self._changesObserverSignal.sendNext(e)
        self._dispatchNextValue()
    }
    
    private func _dispatchFlatChange(e: FlatMutableCollectionChange<T>) {
        self._flatChangesObserver.sendNext(e)
        self._flatChangesObserverSignal.sendNext(e)
        self._changesObserver.sendNext(e.asDeepChange)
        self._changesObserverSignal.sendNext(e.asDeepChange)
        self._dispatchNextValue()
    }
    
    private func _dispatchNextValue() {
        self._valueObserver.sendNext(self.items)
        self._valueObserverSignal.sendNext(self.items)
    }
    
    private func assertIndexPathNotEmpty(indexPath: [Int]) {
        if indexPath.count == 0 {
            fatalError("Got indexPath of length == 0")
        }
    }
    
    internal func _getSubsection(atIndex index: Int) throws -> MutableCollectionSectionProtocol {
        guard let section = self._items[index] as? MutableCollectionSectionProtocol else {
            throw MutableCollectionSectionError.CantGetChild(type: String(self._items[index].dynamicType))
        }
        return section
    }
    
    internal func _insert<Z>(el: Z, atIndexPath indexPath: [Int]) throws {
        if indexPath.count > 1 {
            var section = try self._getSubsection(atIndex: indexPath.first!)
            let range = Range(start: indexPath.first!, end: indexPath.first! + 1)
            try section._insert(el, atIndexPath: Array(indexPath.dropFirst()))
            return self._items.replaceRange(range, with: [section as! T])
        }
        guard let elT = el as? T else {
            let elementType = String(el.dynamicType)
            let sectionType = String(T.self)
            throw MutableCollectionSectionError.CantInsertElementOfType(elementType: elementType, sectionType: sectionType)
        }
        self._items.insert(elT, atIndex: indexPath.first!)
    }
    
    internal func _getItem<Z>(atIndexPath indexPath: [Int]) throws -> Z {
        if indexPath.count > 1 {
            let section = try self._getSubsection(atIndex: indexPath.first!)
            return try section._getItem(atIndexPath: Array(indexPath.dropFirst()))
        }
        guard let result = self._items[indexPath.first!] as? Z else {
            let type = String(self._items[indexPath.first!].dynamicType)
            let targetType = String(Z.self)
            throw MutableCollectionSectionError.CantCastValue(type: type, targetType: targetType)
        }
        return result
    }
    
    internal func _removeItem<Z>(atIndexPath indexPath: [Int]) throws -> Z {
        if indexPath.count > 1 {
            let section = try self._getSubsection(atIndex: indexPath.first!)
            return try section._removeItem(atIndexPath: Array(indexPath.dropFirst()))
        }
        let deletedElement = self._items.removeAtIndex(indexPath.first!)
        guard let deletedElementZ = deletedElement as? Z else {
            let type = String(deletedElement.dynamicType)
            let targetType = String(Z.self)
            throw MutableCollectionSectionError.CantCastValue(type: type, targetType: targetType)
        }
        return deletedElementZ
    }
    
    
    internal func handleChange(change: MutableCollectionChange) {
//        for parent in self._parents {
//            parent.handleChange(change)
//        }
    }
    
    
    // MARK: - Public methods
    
    public subscript(index: Int) -> T {
        return self[index]
    }
    
    public func objectAtIndexPath<Z>(indexPath: [Int]) -> Z {
        return try! self._getItem(atIndexPath: indexPath)
    }
    
    public func objectAtIndexPath<Z>(indexPath: NSIndexPath) -> Z {
        return self.objectAtIndexPath(indexPath.asArray)
    }
    
    public func insert(newElement: T, atIndex index: Int) {
        self._lock.lock()
        self._items.insert(newElement, atIndex: index)
        self._dispatchFlatChange(.Insert(index, newElement))
        self._lock.unlock()
    }
    
    public func insert<Z>(newElement: Z, atIndexPath indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._lock.lock()
        try! self._insert(newElement, atIndexPath: indexPath)
        self._dispatchDeepChange(.Insert(indexPath, newElement))
        self._lock.unlock()
    }
    
    public func insert<Z>(newElement: Z, atIndexPath indexPath: NSIndexPath) {
        self.insert(newElement, atIndexPath: indexPath.asArray)
    }
    
    public func removeAtIndex(index: Int) {
        self._lock.lock()
        let deletedElement = self._items.removeAtIndex(index)
        self._dispatchFlatChange(.Remove(index, deletedElement))
        self._lock.unlock()
    }
    
    public func removeAtIndexPath(indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._lock.lock()
        let deletedElement: String = try! self._removeItem(atIndexPath: indexPath)
        self._dispatchDeepChange(.Remove(indexPath, deletedElement))
        self._lock.unlock()
    }
    
    public func removeAtIndexPath(indexPath: NSIndexPath) {
        self.removeAtIndexPath(indexPath.asArray)
    }
    
    public func removeFirst() {
        if (self._items.count == 0) { return }
        self._lock.lock()
        let deletedElement = self._items.removeFirst()
        self._dispatchFlatChange(.Remove(0, deletedElement))
        self._lock.unlock()
    }
    
    public func removeLast() {
        self._lock.lock()
        if (self._items.count == 0) { return }
        let index = self._items.count - 1
        let deletedElement = self._items.removeLast()
        self._dispatchFlatChange(.Remove(index, deletedElement))
        self._lock.unlock()
    }
    
    public func removeAll() {
        self._lock.lock()
        let copiedValue = self._items
        self._items.removeAll()
        self._dispatchFlatChange(.Composite(copiedValue.enumerate().map { FlatMutableCollectionChange.Remove($0, $1) }))
        self._lock.unlock()
    }
    
    public func append(element: T) {
        self._lock.lock()
        self._items.append(element)
        self._dispatchFlatChange(.Insert(self._items.count - 1, element))
        self._lock.unlock()
    }
    
    public func appendContentsOf(elements: [T]) {
        self._lock.lock()
        let count = self._items.count
        self._items.appendContentsOf(elements)
        self._dispatchFlatChange(.Composite(elements.enumerate().map { FlatMutableCollectionChange.Insert(count + $0, $1) }))
        self._lock.unlock()
    }
    
    public func replace(subRange: Range<Int>, with elements: [T]) {
        self._lock.lock()
        precondition(subRange.startIndex + subRange.count <= self._items.count, "Range out of bounds")
        var insertsComposite: [FlatMutableCollectionChange<T>] = []
        var deletesComposite: [FlatMutableCollectionChange<T>] = []
        for (index, element) in elements.enumerate() {
            let replacedElement = self._items[subRange.startIndex+index]
            self._items.replaceRange(Range<Int>(start: subRange.startIndex+index, end: subRange.startIndex+index+1), with: [element])
            deletesComposite.append(.Remove(subRange.startIndex + index, replacedElement))
            insertsComposite.append(.Insert(subRange.startIndex + index, element))
        }
        self._dispatchFlatChange(.Composite(deletesComposite + insertsComposite))
        self._lock.unlock()
    }
    
    public func replace<Z>(element element: Z, atIndexPath indexPath: [Int]) {
        self._lock.lock()
        let deletedElement: Z = try! self._removeItem(atIndexPath: indexPath)
        try! self._insert(element, atIndexPath: indexPath)
        self._dispatchDeepChange(.Composite([.Remove(indexPath, deletedElement), .Insert(indexPath, element)]))
        self._lock.unlock()
    }
    
    public func replace<Z>(element element: Z, atIndexPath indexPath: NSIndexPath) {
        self.replace(element: element, atIndexPath: indexPath.asArray)
    }
    
    public func move(fromIndex sourceIndex: Int, toIndex targetIndex: Int) -> T {
        self._lock.lock()
        let deletedElement = self._items.removeAtIndex(sourceIndex)
        self._items.insert(deletedElement, atIndex: targetIndex)
        self._dispatchFlatChange(.Composite([.Remove(sourceIndex, deletedElement), .Insert(targetIndex, deletedElement)]))
        self._lock.unlock()
        return deletedElement
    }
    
    public func move(fromIndexPath sourceIndexPath: [Int], toIndexPath targetIndexPath: [Int]) {
        self._lock.lock()
        let deletedElement: Any = try! self._removeItem(atIndexPath: sourceIndexPath)
        try! self._insert(deletedElement, atIndexPath: targetIndexPath)
        self._dispatchDeepChange(.Composite([.Remove(sourceIndexPath, deletedElement), .Insert(targetIndexPath, deletedElement)]))
        self._lock.unlock()
    }
    
    public func move(fromIndexPath sourceIndexPath: NSIndexPath, toIndexPath targetIndexPath: NSIndexPath) {
        self.move(fromIndexPath: sourceIndexPath.asArray, toIndexPath: targetIndexPath.asArray)
    }
    
}


public func ==<T: Equatable>(a: MutableCollectionProperty<T>, b: MutableCollectionProperty<T>) -> Bool {
    return a._items == b._items
}

private extension NSIndexPath {
    var asArray: [Int] {
        let arr = Array(count: self.length, repeatedValue: 0)
        self.getIndexes(UnsafeMutablePointer<Int>(arr))
        return arr
    }
}


