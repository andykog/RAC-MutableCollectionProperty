import Foundation

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
    
    internal func increasedDepth(index: Int) -> MutableCollectionChange {
        switch self {
        case .Remove(let indexPath, let element): return .Remove([index] + indexPath, element)
        case .Insert(let indexPath, let element): return .Insert([index] + indexPath, element)
        case .Composite(let changes): return .Composite(changes.map { $0.increasedDepth(index) })
        }
    }

}
