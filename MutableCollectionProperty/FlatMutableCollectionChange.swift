import Foundation

public enum FlatMutableCollectionChange<T> {
    case Remove(Int, T)
    case Insert(Int, T)
    case Update(Int, T, T)
    case Composite([FlatMutableCollectionChange])
    
    public var index: Int? {
        switch self {
        case .Remove(let index, _): return index
        case .Insert(let index, _): return index
        case .Update(let index, _, _): return index
        default: return nil
        }
    }
    
    public var oldElement: T? {
        switch self {
        case .Remove(_, let oldElement): return oldElement
        case .Insert(_,  _): return nil
        case .Update(_, let oldElement, _): return oldElement
        default: return nil
        }
    }
    
    public var newElement: T? {
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
    
}
