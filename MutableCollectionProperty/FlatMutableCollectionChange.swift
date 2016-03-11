import Foundation

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
