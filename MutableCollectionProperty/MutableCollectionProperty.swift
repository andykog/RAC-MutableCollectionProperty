import Foundation
import ReactiveCocoa
import enum Result.NoError

public enum MutableCollectionChangeOperation {
    case Insertion, Removal
}

public enum FlatMutableCollectionChange<T> {
    case Remove(Int, T)
    case Insert(Int, T)
    case Composite([FlatMutableCollectionChange])
    
    public var index: Int? {
        switch self {
        case .Remove(let index, _): return index
        case .Insert(let index, _): return index
        default: return nil
        }
    }
    
    public var element: T? {
        switch self {
        case .Remove(_, let element): return element
        case .Insert(_, let element): return element
        default: return nil
        }
    }
    
    public var operation: MutableCollectionChangeOperation? {
        switch self {
        case .Insert(_, _): return .Insertion
        case .Remove(_, _): return .Removal
        default: return nil
        }
    }
    
    public var asDeepChange: MutableCollectionChange {
        switch self {
        case .Remove(let(index, el)): return .Remove([index], el)
        case .Insert(let(index, el)): return .Insert([index], el)
        case .Composite(let (changes)): return .Composite(changes.map { $0.asDeepChange })
        }
    }
    
}

public enum MutableCollectionChange {
    case Remove([Int], Any)
    case Insert([Int], Any)
    case Composite([MutableCollectionChange])
    
    public var indexPath: [Int]? {
        switch self {
        case .Remove(let indexPath, _): return indexPath
        case .Insert(let indexPath, _): return indexPath
        default: return nil
        }
    }
    
    public var element: Any? {
        switch self {
        case .Remove(_, let element): return element
        case .Insert(_, let element): return element
        default: return nil
        }
    }
    
    public var operation: MutableCollectionChangeOperation? {
        switch self {
        case .Insert(_, _): return .Insertion
        case .Remove(_, _): return .Removal
        default: return nil
        }
    }
}


public final class MutableCollectionProperty<T: Equatable>: PropertyType {

    public typealias Value = [T]

    
    // MARK: - Private attributes

    private var _rootSection: MutableCollectionSection<T>
    private let _valueObserver: Signal<Value, NoError>.Observer
    private let _valueObserverSignal: Signal<Value, NoError>.Observer
    private let _flatChangesObserver: Signal<FlatMutableCollectionChange<Value.Element>, NoError>.Observer
    private let _flatChangesObserverSignal: Signal<FlatMutableCollectionChange<Value.Element>, NoError>.Observer
    private let _changesObserver: Signal<MutableCollectionChange, NoError>.Observer
    private let _changesObserverSignal: Signal<MutableCollectionChange, NoError>.Observer
    private let _lock = NSRecursiveLock()
    

    // MARK: - Public Attributes

    public var producer: SignalProducer<Value, NoError>
    public var signal: Signal<Value, NoError>
    public var flatChanges: SignalProducer<FlatMutableCollectionChange<Value.Element>, NoError>
    public var flatChangesSignal: Signal<FlatMutableCollectionChange<Value.Element>, NoError>
    public var changes: SignalProducer<MutableCollectionChange, NoError>
    public var changesSignal: Signal<MutableCollectionChange, NoError>
    public var value: Value {
        get {
            return self._rootSection._items
        }
        set {
            let diffResult = self.value.diff(newValue)
            self._rootSection._items = newValue
            self._valueObserver.sendNext(newValue)
            self._flatChangesObserver.sendNext(.Composite(diffResult))
        }
    }

    // MARK: - Init/Deinit

    public init(_ section: MutableCollectionSection<T>) {
        self._lock.name = "org.reactivecocoa.ReactiveCocoa.MutableCollectionProperty"
        self._rootSection = section
        (self.producer, self._valueObserver) = SignalProducer<Value, NoError>.buffer(1)
        (self.flatChanges, self._flatChangesObserver) = SignalProducer<FlatMutableCollectionChange<Value.Element>, NoError>.buffer(1)
        (self.signal, self._valueObserverSignal) = Signal<Value, NoError>.pipe()
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
    
    convenience init(_ items: [T]) {
        self.init(MutableCollectionSection(items))
    }
    
    
    
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
        self._valueObserver.sendNext(self._rootSection.items)
        self._valueObserverSignal.sendNext(self._rootSection.items)
    }
    
    private func assertIndexPathNotEmpty(indexPath: [Int]) {
        if indexPath.count == 0 {
            fatalError("Got indexPath of length == 0")
        }
    }
    
    
    // MARK: - Public methods
    
    
    public func insert(newElement: T, atIndex index: Int) {
        self._lock.lock()
        self._rootSection._items.insert(newElement, atIndex: index)
        self._dispatchFlatChange(.Insert(index, newElement))
        self._lock.unlock()
    }
    
    public func insert<Z: Equatable>(newElement: Z, atIndexPath indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._lock.lock()
        try! self._rootSection._insert(newElement, atIndexPath: indexPath)
        self._dispatchDeepChange(.Insert(indexPath, newElement))
        self._lock.unlock()
    }

    public func removeAtIndex(index: Int) {
        self._lock.lock()
        let deletedElement = self._rootSection._items.removeAtIndex(index)
        self._dispatchFlatChange(.Remove(index, deletedElement))
        self._lock.unlock()
    }
    
    public func removeAtIndexPath(indexPath: [Int]) {
        self.assertIndexPathNotEmpty(indexPath)
        self._lock.lock()
        try! self._dispatchDeepChange(.Remove(indexPath, self._rootSection._removeItem(atIndexPath: indexPath)))
        self._lock.unlock()
    }
    
    public func removeFirst() {
        if (self._rootSection._items.count == 0) { return }
        self._lock.lock()
        let deletedElement = self._rootSection._items.removeFirst()
        self._dispatchFlatChange(.Remove(0, deletedElement))
        self._lock.unlock()
    }

    public func removeLast() {
        self._lock.lock()
        if (self._rootSection._items.count == 0) { return }
        let index = self._rootSection._items.count - 1
        let deletedElement = self._rootSection._items.removeLast()
        self._dispatchFlatChange(.Remove(index, deletedElement))
        self._lock.unlock()
    }
    
    public func removeAll() {
        self._lock.lock()
        let copiedValue = self._rootSection._items
        self._rootSection._items.removeAll()
        self._dispatchFlatChange(.Composite(copiedValue.enumerate().map { FlatMutableCollectionChange.Remove($0, $1) }))
        self._lock.unlock()
    }

    public func append(element: T) {
        self._lock.lock()
        self._rootSection._items.append(element)
        self._dispatchFlatChange(.Insert(self._rootSection._items.count - 1, element))
        self._lock.unlock()
    }
    
    public func appendContentsOf(elements: [T]) {
        self._lock.lock()
        let count = self._rootSection._items.count
        self._rootSection._items.appendContentsOf(elements)
        self._dispatchFlatChange(.Composite(elements.enumerate().map { FlatMutableCollectionChange.Insert(count + $0, $1) }))
        self._lock.unlock()
    }
    
    public func replace(subRange: Range<Int>, with elements: [T]) {
        self._lock.lock()
        precondition(subRange.startIndex + subRange.count <= self._rootSection._items.count, "Range out of bounds")
        var insertsComposite: [FlatMutableCollectionChange<T>] = []
        var deletesComposite: [FlatMutableCollectionChange<T>] = []
        for (index, element) in elements.enumerate() {
            let replacedElement = self._rootSection._items[subRange.startIndex+index]
            self._rootSection._items.replaceRange(Range<Int>(start: subRange.startIndex+index, end: subRange.startIndex+index+1), with: [element])
            deletesComposite.append(.Remove(subRange.startIndex + index, replacedElement))
            insertsComposite.append(.Insert(subRange.startIndex + index, element))
        }
        self._dispatchFlatChange(.Composite(deletesComposite + insertsComposite))
        self._lock.unlock()
    }
}


