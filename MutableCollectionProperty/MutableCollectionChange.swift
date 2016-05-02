import Foundation

public enum MutableCollectionChange {
    case Remove([Int], Any)
    case Insert([Int], Any)
    case Update([Int], Any, Any)
    case Composite([MutableCollectionChange])
    
    public var indexPath: [Int]? {
        switch self {
        case .Remove(let indexPath, _): return indexPath
        case .Insert(let indexPath, _): return indexPath
        case .Update(let indexPath, _, _): return indexPath
        default: return nil
        }
    }
    
    public var oldElement: Any? {
        switch self {
        case .Remove(_, let oldElement): return oldElement
        case .Insert(_, _): return nil
        case .Update(_, let oldElement, _): return oldElement
        default: return nil
        }
    }
    
    public var newElement: Any? {
        switch self {
        case .Remove(_, _): return nil
        case .Insert(_, let newElement): return newElement
        case .Update(_, _, let newElement): return newElement
        default: return nil
        }

    }
    
    public var operation: MutableCollectionChangeOperation? {
        switch self {
        case .Insert(_, _): return .Insertion
        case .Remove(_, _): return .Removal
        case .Update(_, _, _): return .Update
        default: return nil
        }
    }
    
    // The same change event but with indexPath prepended by given index
    internal func increasedDepth(index: Int) -> MutableCollectionChange {
        switch self {
        case .Remove(let indexPath, let element): return .Remove([index] + indexPath, element)
        case .Insert(let indexPath, let element): return .Insert([index] + indexPath, element)
        case .Update(let indexPath, let oldElement, let newElement): return .Update([index] + indexPath, oldElement, newElement)
        case .Composite(let changes): return .Composite(changes.map { $0.increasedDepth(index) })
        }
    }
    
    // Current deep change converted to flat change
    internal func flat<Z>() -> FlatMutableCollectionChange<Z>? {
        switch self {
        case .Remove(let indexPath, let el):
            if indexPath.count > 1 { return nil }
            return .Remove(indexPath.first!, el as! Z)
        case .Insert(let indexPath, let el):
            if indexPath.count > 1 { return nil }
            return .Insert(indexPath.first!, el as! Z)
        case .Update(let indexPath, let oldEl, let newEl):
            if indexPath.count > 1 { return nil }
            return .Update(indexPath.first!, oldEl as! Z, newEl as! Z)
        case .Composite(let changes):
            return .Composite(changes.map({ $0.flat() }).filter({ $0 != nil }).map({ $0! }))
        }
    }

}
