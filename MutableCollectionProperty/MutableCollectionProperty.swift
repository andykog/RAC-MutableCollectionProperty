import Foundation
import ReactiveCocoa
import Result

public enum CollectionChange<T> {
    case Remove(Int, T)
    case Insert(Int, T)
    case Composite([CollectionChange])
    
    public func index() -> Int? {
        switch self {
        case .Remove(let index, _): return index
        case .Insert(let index, _): return index
        default: return nil
        }
    }
    
    public func element() -> T? {
        switch self {
        case .Remove(_, let element): return element
        case .Insert(_, let element): return element
        default: return nil
        }
    }
}

public final class MutableCollectionProperty<T: Equatable>: PropertyType {

    public typealias Value = [T]

    
    // MARK: - Private attributes

    private let _valueObserver: Signal<Value, NoError>.Observer
    private let _valueObserverSignal: Signal<Value, NoError>.Observer
    private let _changesObserver: Signal<CollectionChange<Value.Element>, NoError>.Observer
    private let _changesObserverSignal: Signal<CollectionChange<Value.Element>, NoError>.Observer
    private var _value: Value
    private let _lock = NSRecursiveLock()

    // MARK: - Public Attributes

    public var producer: SignalProducer<Value, NoError>
    public var signal: Signal<Value, NoError>
    public var changes: SignalProducer<CollectionChange<Value.Element>, NoError>
    public var changesSignal: Signal<CollectionChange<Value.Element>, NoError>
    public var value: Value {
        get {
            let value = _value
            return value
        }
        set {
            let diffResult = value.diff(newValue)
            _value = newValue
            _valueObserver.sendNext(newValue)
            _changesObserver.sendNext(.Composite(diffResult))
        }
    }

    // MARK: - Init/Deinit

    public init(_ initialValue: Value) {
        _lock.name = "org.reactivecocoa.ReactiveCocoa.MutableCollectionProperty"
        _value = initialValue
        (producer, _valueObserver) = SignalProducer<Value, NoError>.buffer(1)
        (changes, _changesObserver) = SignalProducer<CollectionChange<Value.Element>, NoError>.buffer(1)
        (signal, _valueObserverSignal) = Signal<Value, NoError>.pipe()
        (changesSignal, _changesObserverSignal) = Signal<CollectionChange<Value.Element>, NoError>.pipe()
    }

    deinit {
        _valueObserver.sendCompleted()
        _valueObserverSignal.sendCompleted()
        _changesObserver.sendCompleted()
        _changesObserverSignal.sendCompleted()
    }
    
    
    // MARK: - Public

    public func removeFirst() {
        if (_value.count == 0) { return }
        _lock.lock()
        let deletedElement = _value.removeFirst()
        _changesObserver.sendNext(.Remove(0, deletedElement))
        _changesObserverSignal.sendNext(.Remove(0, deletedElement))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }

    public func removeLast() {
        _lock.lock()
        if (_value.count == 0) { return }
        let index = _value.count - 1
        let deletedElement = _value.removeLast()
        _changesObserver.sendNext(.Remove(index, deletedElement))
        _changesObserverSignal.sendNext(.Remove(index, deletedElement))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
    
    public func removeAll() {
        _lock.lock()
        let copiedValue = _value
        _value.removeAll()
        _changesObserver.sendNext(.Composite(copiedValue.mapWithIndex{CollectionChange.Remove($0, $1)}))
        _changesObserverSignal.sendNext(.Composite(copiedValue.mapWithIndex{CollectionChange.Remove($0, $1)}))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }

    public func removeAtIndex(index: Int) {
        _lock.lock()
        let deletedElement = _value.removeAtIndex(index)
        _changesObserver.sendNext(CollectionChange.Remove(index, deletedElement))
        _changesObserverSignal.sendNext(CollectionChange.Remove(index, deletedElement))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
    
    public func append(element: T) {
        _lock.lock()
        _value.append(element)
        _changesObserver.sendNext(.Insert(_value.count - 1, element))
        _changesObserverSignal.sendNext(.Insert(_value.count - 1, element))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
    
    public func appendContentsOf(elements: [T]) {
        _lock.lock()
        let count = _value.count
        _value.appendContentsOf(elements)
        _changesObserver.sendNext(.Composite(elements.mapWithIndex{CollectionChange.Insert(count + $0, $1)}))
        _changesObserverSignal.sendNext(.Composite(elements.mapWithIndex{CollectionChange.Insert(count + $0, $1)}))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
    
    public func insert(newElement: T, atIndex index: Int) {
        _lock.lock()
        _value.insert(newElement, atIndex: index)
        _changesObserver.sendNext(.Insert(index, newElement))
        _changesObserverSignal.sendNext(.Insert(index, newElement))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
    
    public func replace(subRange: Range<Int>, with elements: [T]) {
        _lock.lock()
        precondition(subRange.startIndex + subRange.count <= _value.count, "Range out of bounds")
        var insertsComposite: [CollectionChange<T>] = []
        var deletesComposite: [CollectionChange<T>] = []
        for (index, element) in elements.enumerate() {
            let replacedElement = _value[subRange.startIndex+index]
            _value.replaceRange(Range<Int>(start: subRange.startIndex+index, end: subRange.startIndex+index+1), with: [element])
            deletesComposite.append(.Remove(subRange.startIndex + index, replacedElement))
            insertsComposite.append(.Insert(subRange.startIndex + index, element))
        }
        _changesObserver.sendNext(.Composite(deletesComposite))
        _changesObserverSignal.sendNext(.Composite(deletesComposite))
        _changesObserver.sendNext(.Composite(insertsComposite))
        _changesObserverSignal.sendNext(.Composite(insertsComposite))
        _valueObserver.sendNext(_value)
        _valueObserverSignal.sendNext(_value)
        _lock.unlock()
    }
}

extension Array where Element: Equatable {
    
    func mapWithIndex<T>(transform: (Int, Element) -> T) -> [T] {
        var newValues: [T] = []
        for (index, element) in self.enumerate() {
            newValues.append(transform(index, element))
        }
        return newValues
    }
    
    /// Returns the sequence of ArrayDiffResults required to transform one array into another.
    public func diff(other: [Element]) -> [CollectionChange<Element>] {
        let table = MemoizedSequenceComparison.buildTable(self, other, self.count, other.count)
        return Array.diffFromIndices(table, self, other, self.count, other.count)
    }
    
    /// Walks back through the generated table to generate the diff.
    private static func diffFromIndices(table: [[Int]], _ x: [Element], _ y: [Element], _ i: Int, _ j: Int) -> [CollectionChange<Element>] {
        if i == 0 && j == 0 {
            return []
        } else if i == 0 {
            return diffFromIndices(table, x, y, i, j-1) + [.Insert(j-1, y[j-1])]
        } else if j == 0 {
            return diffFromIndices(table, x, y, i - 1, j) + [.Remove(i-1, x[i-1])]
        } else if table[i][j] == table[i][j-1] {
            return diffFromIndices(table, x, y, i, j-1) + [.Insert(j-1, y[j-1])]
        } else if table[i][j] == table[i-1][j] {
            return diffFromIndices(table, x, y, i - 1, j) + [.Remove(i-1, x[i-1])]
        } else {
            return diffFromIndices(table, x, y, i-1, j-1)
        }
    }
    
}

struct MemoizedSequenceComparison<T: Equatable> {
    static func buildTable(x: [T], _ y: [T], _ n: Int, _ m: Int) -> [[Int]] {
        var table = Array(count: n + 1, repeatedValue: Array(count: m + 1, repeatedValue: 0))
        for i in 0...n {
            for j in 0...m {
                if (i == 0 || j == 0) {
                    table[i][j] = 0
                }
                else if x[i-1] == y[j-1] {
                    table[i][j] = table[i-1][j-1] + 1
                } else {
                    table[i][j] = max(table[i-1][j], table[i][j-1])
                }
            }
        }
        return table
    }
}
