import Foundation

private func buildMemoizedSequenceComparisonTable<T>(x: [T], _ y: [T], _ n: Int, _ m: Int) -> [[Int]] {
    var table = Array(count: n + 1, repeatedValue: Array(count: m + 1, repeatedValue: 0))
    for i in 0...n {
        for j in 0...m {
            if (i == 0 || j == 0) {
                table[i][j] = 0
            }
            else if let a = x[i-1] as? NSObject,
                b = y[j-1] as? NSObject
                where a == b
            {
                table[i][j] = table[i-1][j-1] + 1
            } else {
                table[i][j] = max(table[i-1][j], table[i][j-1])
            }
        }
    }
    return table
}


internal extension Array {
    
    /// Returns the sequence of ArrayDiffResults required to transform one array into another.
    func diff(other: [Element]) -> [FlatMutableCollectionChange<Element>] {
        let table = buildMemoizedSequenceComparisonTable(self, other, self.count, other.count)
        return Array.diffFromIndices(table, self, other, self.count, other.count)
    }
    
    /// Walks back through the generated table to generate the diff.
    private static func diffFromIndices(table: [[Int]], _ x: [Element], _ y: [Element], _ i: Int, _ j: Int) -> [FlatMutableCollectionChange<Element>] {
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