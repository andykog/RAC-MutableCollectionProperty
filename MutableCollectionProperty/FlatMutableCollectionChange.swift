import Foundation

public enum FlatMutableCollectionChange<T> {
    case Remove(Int, T)
    case Insert(Int, T)
    case Update(Int, T)
    case Composite([FlatMutableCollectionChange])
    
    public var index: Int? {
        switch self {
        case .Remove(let index, _): return index
        case .Insert(let index, _): return index
        case .Update(let index, _): return index
        default: return nil
        }
    }
    
    public var element: T? {
        switch self {
        case .Remove(_, let element): return element
        case .Insert(_, let element): return element
        case .Update(_, let element): return element
        default: return nil
        }
    }
    
    public var operation: MutableCollectionChangeOperation? {
        switch self {
        case .Insert(_, _): return .Insertion
        case .Remove(_, _): return .Removal
        case .Update(_, _): return .Update
        default: return nil
        }
    }
    
}
