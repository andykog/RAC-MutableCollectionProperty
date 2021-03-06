import Foundation
import ReactiveCocoa
import enum Result.NoError

/// Like Hashable, but withoud conformance to Equatable protocol
internal protocol WithID: class {
    var id: Int { get }
}

/// A protocol to be used instead of real class, where using generic is impossible
internal protocol MutableCollectionProtocol: WithID {
    var _parents: WeakSet { get set }
    
    func _getSubCollection(atIndex _: Int) throws -> MutableCollectionProtocol
    func _getSubCollection(atIndexPath _: [Int]) throws -> MutableCollectionProtocol
    func _getAnyItem(_: Int) -> Any
    func _indexOfAny(predicate: Any -> Bool) -> Int?
    
    func _insert(anyElement newElement: Any, atIndex index: Int) throws
    func _remove(atIndex index: Int) -> Any
    func _replace(anyElementAtIndex index: Int, withElement element: Any) throws -> Any
    
    func _handleChange(_: MutableCollectionChange)
    
    func _connectChildSubcollection(element: Any)
    func _connectChildSubcollections(elements: [Any])
}

/// Errors enum
public enum MutableCollectionError: ErrorType, CustomStringConvertible {
    case CantGetChild(type: String)
    case CantInsertElementOfType(elementType: String, sectionType: String)
    case CantReplaceWithElementOfType(elementType: String, sectionType: String)
    
    public var description: String {
        switch self {
        case .CantGetChild(type: let type):
            return "Can't get child of an element of type \(type)"
        case .CantInsertElementOfType(elementType: let elementType, sectionType: let sectionType):
            return "Attempt to inset element of type \(elementType) in section of type \(sectionType)"
        case .CantReplaceWithElementOfType(elementType: let elementType, sectionType: let sectionType):
            return "Attempt to replace with element of type \(elementType) in section of type \(sectionType)"
        }
    }
}

public class MutableCollectionProperty<T>: MutablePropertyType, MutableCollectionProtocol {
    
    public typealias Value = [T]
    
    public let id: Int
    
    public init (_ items: [T]) {
        self._items = items
        self.id = Int(arc4random_uniform(6) + 1)
        self._lock.name = "org.reactivecocoa.ReactiveCocoa.MutableCollectionProperty"
        (self.producer, self._valueObserver) = SignalProducer<[T], NoError>.buffer(1)
        (self.signal, self._valueObserverSignal) = Signal<[T], NoError>.pipe()
        (self.flatChanges, self._flatChangesObserver) = SignalProducer<FlatMutableCollectionChange<T>, NoError>.buffer(1)
        (self.flatChangesSignal, self._flatChangesObserverSignal) = Signal<FlatMutableCollectionChange<T>, NoError>.pipe()
        (self.changes, self._changesObserver) = SignalProducer.buffer(1)
        (self.changesSignal, self._changesObserverSignal) = Signal.pipe()
        self._connectChildSubcollections(items)
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
    private let _valueObserver: Signal<[T], NoError>.Observer
    private let _valueObserverSignal: Signal<[T], NoError>.Observer
    private let _flatChangesObserver: Signal<FlatMutableCollectionChange<T>, NoError>.Observer
    private let _flatChangesObserverSignal: Signal<FlatMutableCollectionChange<T>, NoError>.Observer
    private let _changesObserver: Signal<MutableCollectionChange, NoError>.Observer
    private let _changesObserverSignal: Signal<MutableCollectionChange, NoError>.Observer
    private let _lock = NSRecursiveLock()
    private var _changesQuee: [MutableCollectionChange] = []
    
    
    // MARK: - Internal attributes
    
    internal var _parents = WeakSet()
    
    
    // MARK: - Public Attributes
    
    public var producer: SignalProducer<[T], NoError>
    public var signal: Signal<[T], NoError>
    public var flatChanges: SignalProducer<FlatMutableCollectionChange<T>, NoError>
    public var flatChangesSignal: Signal<FlatMutableCollectionChange<T>, NoError>
    public var changes: SignalProducer<MutableCollectionChange, NoError>
    public var changesSignal: Signal<MutableCollectionChange, NoError>
    
    /// When this value is `true`, MutableCollectionProperty won't dispatch any change events untill it is set to `false`.
    /// After it is set back to `false`, MutableCollectionProperty dispatches .Composite event, containing all the skipped events.
    public var isUpdating = false {
        didSet {
            if self.isUpdating == oldValue { return }
            if self.isUpdating  {
                self._lock.lock()
            } else {
                self._lock.unlock()
                self._dispatchChanges()
            }
        }
    }
    
    public var items: [T] {
        get {
            return self._items
        }
        set {
            self._transition {
                let diffResult = self.items.diff(newValue)
                self._items = newValue
                self._connectChildSubcollections(newValue)
                self._handleChange(.Composite(diffResult))
                self._valueObserver.sendNext(newValue)
            }
        }
    }
    
    /// Alias to `items` for MutablePropertyType protocol conformance
    public var value: Value {
        get {
            return self.items
        }
        set {
            self.items = newValue
        }
    }
    
    
    // MARK: - Private methods
    
    /// Executes given closure in `isUpdating` environment (see isUpdating)
    private func _transition<Z>(closure: () -> Z) -> Z {
        if self.isUpdating {
            return closure()
        } else {
            self.isUpdating = true
            let output = closure()
            self.isUpdating = false
            return output
        }
    }
    
    /// Dispatches event, indicating that self.items was changed
    private func _dispatchNextValue() {
        self._valueObserver.sendNext(self.items)
        self._valueObserverSignal.sendNext(self.items)
    }
    
    /// Dispatches events, accumulated in self._changesQuee (if any)
    private func _dispatchChanges() {
        if (self._changesQuee.count > 0) {
            let change: MutableCollectionChange = self._changesQuee.count > 1
                ? MutableCollectionChange.Composite(self._changesQuee)
                : self._changesQuee.first!
            if let flatChange: FlatMutableCollectionChange<T> = change.flat() {
                self._flatChangesObserver.sendNext(flatChange)
                self._flatChangesObserverSignal.sendNext(flatChange)
            }
            self._changesQuee = []
            self._changesObserver.sendNext(change)
            self._changesObserverSignal.sendNext(change)
            self._dispatchNextValue()
        }
    }
    
    private func _assertIndexPathNotEmpty(indexPath: [Int]) {
        if indexPath.count == 0 {
            fatalError("Got indexPath of length == 0")
        }
    }
    
    /// Sets self as given child parent
    internal func _connectChildSubcollection(element: Any) {
        if let section = element as? MutableCollectionProtocol {
            section._parents.insert(self)
        }
    }
    
    /// Sets self as given children parent
    internal func _connectChildSubcollections(elements: [Any]) {
        for element in elements {
            self._connectChildSubcollection(element)
        }
    }
    
    /// Sets self as given children parent
    private func _connectChildSubcollections(elements: [T]) {
        for element in elements {
            self._connectChildSubcollection(element)
        }
    }

    
    // MARK: - Internal methods
    
    /// Passes event to parent, adds it to quee and dispatches it if `isUpdating` is false.
    internal func _handleChange(change: MutableCollectionChange) {
        self._changesQuee.append(change)
        for parent in self._parents {
            if let parent = parent as? MutableCollectionProtocol {
                if let index = parent._indexOfAny({ $0 as? AnyObject === self }) {
                    parent._handleChange(change.increasedDepth(index))
                }
            }
        }
        if self.isUpdating == false { // otherwise changes will be dispatched on update finished
            self._dispatchChanges()
        }
    }
    
    /// Returns child at index, if it adopts `MutableCollectionProtocol`, otherwise throws
    internal func _getSubCollection(atIndex index: Int) throws -> MutableCollectionProtocol {
        guard let section = self._items[index] as? MutableCollectionProtocol else {
            throw MutableCollectionError.CantGetChild(type: String(self._items[index].dynamicType))
        }
        return section
    }
    
    /// Returns child at indexPath, if it adopts `MutableCollectionProtocol`, otherwise throws
    internal func _getSubCollection(atIndexPath indexPath: [Int]) throws -> MutableCollectionProtocol {
        if indexPath.count == 0 {
            return self
        }
        if indexPath.count > 1 {
            return try self._getSubCollection(atIndex: indexPath.first!)._getSubCollection(atIndexPath: Array(indexPath.dropFirst()))
        } else {
            return try self._getSubCollection(atIndex: indexPath.first!)
        }
    }
    
    /// Returns child at given index as `Any`
    internal func _getAnyItem(index: Int) -> Any {
        return self._items[index]
    }
    
    /// Inserts element at index
    internal func _insert(anyElement newElement: Any, atIndex index: Int) throws {
        guard let elT = newElement as? T else {
            let elementType = String(newElement.dynamicType)
            let sectionType = String(T.self)
            throw MutableCollectionError.CantInsertElementOfType(elementType: elementType, sectionType: sectionType)
        }
        self._items.insert(elT, atIndex: index)
    }
    
    /// Replaces element at index
    internal func _replace(anyElementAtIndex index: Int, withElement element: Any) throws -> Any {
        guard let elT = element as? T else {
            let elementType = String(element.dynamicType)
            let sectionType = String(T.self)
            throw MutableCollectionError.CantReplaceWithElementOfType(elementType: elementType, sectionType: sectionType)
        }
        let removed = self._items.removeAtIndex(index)
        self._items.insert(elT, atIndex: index)
        return removed
    }

    
    /// Remove element at index
    internal func _remove(atIndex index: Int) -> Any {
        return self._items.removeAtIndex(index)
    }
    
    internal func _indexOfAny(predicate: Any -> Bool) -> Int? {
        return self._items.indexOf(predicate)
    }
    
    
    // MARK: - Public methods
    
    
    public func indexOf(predicate: T -> Bool) -> Int? {
        return self._items.indexOf(predicate)
    }

    
    // Getting element
    
    public subscript(index: Int) -> T {
        get {
            return self.items[index]
        }
        set {
            if self._items.indices.contains(index) {
                self.replace(elementAtIndex: index, withElement: newValue)
            } else {
                self.insert(newValue, atIndex: index)
            }
        }
    }
    
    public func objectAtIndexPath(indexPath: [Int]) -> Any {
        return try! self._getSubCollection(atIndexPath: indexPath.withoutLast)._getAnyItem(indexPath.last!)
    }
    
    
    // Insertion

    public func insert(newElement: T, atIndex index: Int) {
        self._transition {
            self._items.insert(newElement, atIndex: index)
            self._connectChildSubcollection(newElement)
            self._handleChange(.Insert([index], newElement))
        }
    }
    
    public func insert(newElement: Any, atIndexPath indexPath: [Int]) {
        self._assertIndexPathNotEmpty(indexPath)
        self._transition {
            let section = try! self._getSubCollection(atIndexPath: indexPath.withoutLast)
            try! section._insert(anyElement: newElement, atIndex: indexPath.last!)
            section._connectChildSubcollection(newElement)
            section._handleChange(.Insert([indexPath[0]], newElement))
        }
    }
    
    
    // Removing

    public func removeAtIndex(index: Int) -> T {
        return self._transition {
            let deletedElement = self._items.removeAtIndex(index)
            self._handleChange(.Remove([index], deletedElement))
            return deletedElement
        }
    }
    
    public func removeAtIndexPath(indexPath: [Int]) -> Any {
        self._assertIndexPathNotEmpty(indexPath)
        return self._transition {
            let section = try! self._getSubCollection(atIndexPath: indexPath.withoutLast)
            let deletedElement = section._remove(atIndex: indexPath.last!)
            section._handleChange(.Remove([indexPath.last!], deletedElement))
            return deletedElement
        }
    }
    
    public func removeFirst() {
        if (self._items.count == 0) { return }
        self._transition {
            let deletedElement = self._items.removeFirst()
            self._handleChange(.Remove([0], deletedElement))
        }
    }
    
    public func removeLast() {
        if (self._items.count == 0) { return }
        self._transition {
            let index = self._items.count - 1
            let deletedElement = self._items.removeLast()
            self._handleChange(.Remove([index], deletedElement))
        }
    }
    
    public func removeAll() {
        self._transition {
            let copiedValue = self._items
            self._items.removeAll()
            self._handleChange(.Composite(copiedValue.enumerate().map { MutableCollectionChange.Remove([$0], $1) }))
        }
    }
    
    
    // Appending
    
    public func append(element: T) {
        self._transition {
            self._items.append(element)
            self._connectChildSubcollection(element)
            self._handleChange(.Insert([self._items.count - 1], element))
        }
    }
    
    public func appendContentsOf(elements: [T]) {
        self._transition {
            let count = self._items.count
            self._items.appendContentsOf(elements)
            self._connectChildSubcollections(elements)
            self._handleChange(.Composite(elements.enumerate().map { MutableCollectionChange.Insert([count + $0], $1) }))
        }
    }
    
    
    // Replacing

    public func replace(subRange: Range<Int>, with elements: [T]) {
        self._transition {
            precondition(subRange.startIndex + subRange.count <= self._items.count, "Range out of bounds")
            for (index, element) in elements.enumerate() {
                let oldElement = self._items.removeAtIndex(subRange.startIndex+index)
                self._items.insert(element, atIndex: subRange.startIndex+index)
                self._handleChange(.Update([index], oldElement, element))
            }
            self._connectChildSubcollections(elements)
        }
    }
    
    public func replace(elementAtIndex index: Int, withElement element: T) {
        self._transition {
            let oldElement = self._remove(atIndex: index)
            try! self._insert(anyElement: element, atIndex: index)
            self._connectChildSubcollection(element)
            self._handleChange(.Update([index], oldElement, element))
        }
    }
    
    public func replace(elementAtIndexPath indexPath: [Int], withElement element: Any) {
        self._assertIndexPathNotEmpty(indexPath)
        self._transition {
            let section = try! self._getSubCollection(atIndexPath: indexPath.withoutLast)
            let oldElement = try! section._replace(anyElementAtIndex: indexPath.last!, withElement: element)
            section._connectChildSubcollection(element)
            section._handleChange(.Update([indexPath.last!], oldElement, element))
        }
    }
    
    
    // Moving

    public func move(fromIndex sourceIndex: Int, toIndex targetIndex: Int) {
        self._transition {
            let deletedElement = self._items.removeAtIndex(sourceIndex)
            self._items.insert(deletedElement, atIndex: targetIndex)
            self._handleChange(.Remove([sourceIndex], deletedElement))
            self._handleChange(.Insert([targetIndex], deletedElement))
        }
    }
    
    public func move(fromIndexPath sourceIndexPath: [Int], toIndexPath targetIndexPath: [Int]) {
        self._assertIndexPathNotEmpty(sourceIndexPath)
        self._assertIndexPathNotEmpty(targetIndexPath)
        self._transition {
            let sourceSection = try! self._getSubCollection(atIndexPath: sourceIndexPath.withoutLast)
            let targetSection = try! self._getSubCollection(atIndexPath: targetIndexPath.withoutLast)
            let element = sourceSection._remove(atIndex: sourceIndexPath.last!)
            try! targetSection._insert(anyElement: element, atIndex: targetIndexPath.last!)
            sourceSection._handleChange(.Remove([sourceIndexPath.last!], element))
            targetSection._handleChange(.Insert([targetIndexPath.last!], element))
            if let section = element as? MutableCollectionProtocol where sourceSection !== targetSection {
                section._parents.remove(sourceSection)
                section._parents.insert(targetSection)
            }
        }
    }
    
}


// MARK: - NSIndexPath supporon

public extension MutableCollectionProperty {
    
    public func objectAtIndexPath(indexPath: NSIndexPath) -> Any {
        return self.objectAtIndexPath(indexPath.asArray)
    }
    
    public func removeAtIndexPath(indexPath: NSIndexPath) {
        self.removeAtIndexPath(indexPath.asArray)
    }
    
    public func insert<Z>(newElement: Z, atIndexPath indexPath: NSIndexPath) {
        self.insert(newElement, atIndexPath: indexPath.asArray)
    }
    
    public func replace(elementAtIndexPath indexPath: NSIndexPath, withElement element: Any) {
        self.replace(elementAtIndexPath: indexPath.asArray, withElement: element)
    }
    
    public func move(fromIndexPath sourceIndexPath: NSIndexPath, toIndexPath targetIndexPath: NSIndexPath) {
        self.move(fromIndexPath: sourceIndexPath.asArray, toIndexPath: targetIndexPath.asArray)
    }
    
}


// MARK: - Equatable

public func ==<T: Equatable>(a: MutableCollectionProperty<T>, b: MutableCollectionProperty<T>) -> Bool {
    return a._items == b._items
}


// MARK: - Private extensions

private extension NSIndexPath {
    var asArray: [Int] {
        let arr = Array(count: self.length, repeatedValue: 0)
        self.getIndexes(UnsafeMutablePointer<Int>(arr))
        return arr
    }
}

private extension Array {
    var withoutLast: [Element] {
        return Array(self.dropLast())
    }
}
