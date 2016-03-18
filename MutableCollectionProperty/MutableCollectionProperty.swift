import Foundation
import ReactiveCocoa
import enum Result.NoError

internal protocol WithID: class {
    var id: Int { get }
}

internal protocol MutableCollectionSectionProtocol: WithID {
    var _anyItems: [Any] { get }
    func _getSubsection(atIndex _: Int) throws -> MutableCollectionSectionProtocol
    func _getItem(atIndexPath _: [Int]) throws -> Any
    func _removeItem(atIndexPath _: [Int]) throws -> Any
    func addParent(_: MutableCollectionSectionProtocol)
    func _handleChange(_: MutableCollectionChange)
    func _insert(_: Any, atIndexPath _: [Int]) throws
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

public class MutableCollectionProperty<T>: PropertyType, MutableCollectionSectionProtocol {
    
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
        for item in items {
            if let item = item as? MutableCollectionSectionProtocol {
                item.addParent(self)
            }
        }
    }
    
    func addParent(parent: MutableCollectionSectionProtocol) {
        self._parents.insert(parent)
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
    private var _parents = WeakSet()
    
    
    // MARK: - Internal attributes
    
    internal var _anyItems: [Any] {
        return self.items.map { $0 as Any }
    }
    internal var _changesQuee: [MutableCollectionChange] = []
    
    
    // MARK: - Public Attributes
    
    public var producer: SignalProducer<Value, NoError>
    public var signal: Signal<Value, NoError>
    public var flatChanges: SignalProducer<FlatMutableCollectionChange<Value.Element>, NoError>
    public var flatChangesSignal: Signal<FlatMutableCollectionChange<Value.Element>, NoError>
    public var changes: SignalProducer<MutableCollectionChange, NoError>
    public var changesSignal: Signal<MutableCollectionChange, NoError>
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
    
    public var value: Value {
        get {
            return self._items
        }
        set {
            self._transition {
                let diffResult = self.value.diff(newValue)
                self._items = newValue
                for item in newValue {
                    if let item = item as? MutableCollectionSectionProtocol {
                        item.addParent(self)
                    }
                }
                self._handleChange(.Composite(diffResult))
                self._valueObserver.sendNext(newValue)
            }
        }
    }
    
    public var items: [T] {
        return self._items
    }
    
    public typealias Value = [T]
    
    
    // MARK: - Private methods
    
    private func _transition(closure: () -> Void) {
        if self.isUpdating {
            closure()
        } else {
            self.isUpdating = true
            closure()
            self.isUpdating = false
        }
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
    
    
    // MARK: - Internal methods
    
    internal func _handleChange(change: MutableCollectionChange) {
        self._changesQuee.append(change)
        for parent in self._parents {
            if let parent = parent as? MutableCollectionSectionProtocol {
                if let index = parent._anyItems.indexOf({ $0 as? AnyObject === self }) {
                    parent._handleChange(change.increasedDepth(index))
                }
            }
        }
    }
    
    internal func _getSubsection(atIndex index: Int) throws -> MutableCollectionSectionProtocol {
        guard let section = self._items[index] as? MutableCollectionSectionProtocol else {
            throw MutableCollectionSectionError.CantGetChild(type: String(self._items[index].dynamicType))
        }
        return section
    }
    
    internal func _insert(el: Any, atIndexPath indexPath: [Int]) throws {
        let index = indexPath.first!
        let restIndexPath = Array(indexPath.dropFirst())
        if restIndexPath.count > 0 {
            let section = try self._getSubsection(atIndex: index)
            let range = Range(start: index, end: index + 1)
            try section._insert(el, atIndexPath: restIndexPath)
            return self._items.replaceRange(range, with: [section as! T])
        }
        guard let elT = el as? T else {
            let elementType = String(el.dynamicType)
            let sectionType = String(T.self)
            throw MutableCollectionSectionError.CantInsertElementOfType(elementType: elementType, sectionType: sectionType)
        }
        self._items.insert(elT, atIndex: index)
        self._handleChange(.Insert([index], elT))
    }
    
    internal func _getItem(atIndexPath indexPath: [Int]) throws -> Any {
        let index = indexPath.first!
        let restIndexPath = Array(indexPath.dropFirst())
        if restIndexPath.count > 0 {
            let section = try self._getSubsection(atIndex: index)
            return try section._getItem(atIndexPath: restIndexPath)
        }
        return self._items[index]
    }
    
    internal func _removeItem(atIndexPath indexPath: [Int]) throws -> Any {
        let index = indexPath.first!
        let restIndexPath = Array(indexPath.dropFirst())
        if restIndexPath.count > 0 {
            let section = try self._getSubsection(atIndex: index)
            return try section._removeItem(atIndexPath: restIndexPath)
        }
        let deletedElement = self._items.removeAtIndex(index)
        self._handleChange(.Remove([index], deletedElement))
        return deletedElement
    }
    
    // MARK: - Public methods
    
    public subscript(index: Int) -> T {
        return self.value[index]
    }
    
    public func objectAtIndexPath(indexPath: [Int]) -> Any {
        return try! self._getItem(atIndexPath: indexPath)
    }
    
    public func objectAtIndexPath(indexPath: NSIndexPath) -> Any {
        return self.objectAtIndexPath(indexPath.asArray)
    }
    
    public func insert(newElement: T, atIndex index: Int) {
        self._transition {
            self._items.insert(newElement, atIndex: index)
            self._handleChange(.Insert([index], newElement))
        }
    }
    
    public func insert<Z>(newElement: Z, atIndexPath indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._transition {
            try! self._insert(newElement, atIndexPath: indexPath)
        }
    }
    
    public func insert<Z>(newElement: Z, atIndexPath indexPath: NSIndexPath) {
        self.insert(newElement, atIndexPath: indexPath.asArray)
    }
    
    public func removeAtIndex(index: Int) {
        self._transition {
            let deletedElement = self._items.removeAtIndex(index)
            self._handleChange(.Remove([index], deletedElement))
        }
    }
    
    public func removeAtIndexPath(indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._transition {
            try! self._removeItem(atIndexPath: indexPath)
        }
    }
    
    public func removeAtIndexPath(indexPath: NSIndexPath) {
        self.removeAtIndexPath(indexPath.asArray)
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
    
    public func append(element: T) {
        self._transition {
            self._items.append(element)
            self._handleChange(.Insert([self._items.count - 1], element))
        }
    }
    
    public func appendContentsOf(elements: [T]) {
        self._transition {
            let count = self._items.count
            self._items.appendContentsOf(elements)
            self._handleChange(.Composite(elements.enumerate().map { MutableCollectionChange.Insert([count + $0], $1) }))
        }
    }
    
    public func replace(subRange: Range<Int>, with elements: [T]) {
        self._transition {
            precondition(subRange.startIndex + subRange.count <= self._items.count, "Range out of bounds")
            var insertsComposite: [MutableCollectionChange] = []
            var deletesComposite: [MutableCollectionChange] = []
            for (index, element) in elements.enumerate() {
                let replacedElement = self._items[subRange.startIndex+index]
                self._items.replaceRange(Range<Int>(start: subRange.startIndex+index, end: subRange.startIndex+index+1), with: [element])
                deletesComposite.append(.Remove([subRange.startIndex + index], replacedElement))
                insertsComposite.append(.Insert([subRange.startIndex + index], element))
            }
            self._handleChange(.Composite(deletesComposite + insertsComposite))
        }
    }
    
    public func replace<Z>(element element: Z, atIndexPath indexPath: [Int]) {
        self._transition {
            try! self._removeItem(atIndexPath: indexPath)
            try! self._insert(element, atIndexPath: indexPath)
        }
    }
    
    public func replace<Z>(element element: Z, atIndexPath indexPath: NSIndexPath) {
        self.replace(element: element, atIndexPath: indexPath.asArray)
    }
    
    public func move(fromIndex sourceIndex: Int, toIndex targetIndex: Int) {
        self._transition {
            let deletedElement = self._items.removeAtIndex(sourceIndex)
            self._items.insert(deletedElement, atIndex: targetIndex)
        }
    }
    
    public func move(fromIndexPath sourceIndexPath: [Int], toIndexPath targetIndexPath: [Int]) {
        self._transition {
            let deletedElement: Any = try! self._removeItem(atIndexPath: sourceIndexPath)
            try! self._insert(deletedElement, atIndexPath: targetIndexPath)
        }
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


