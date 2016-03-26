import XCTest
import Quick
import Nimble
import ReactiveCocoa

@testable import MutableCollectionProperty

class WeakSetTests: QuickSpec {
    
    override func spec() {
        
        describe("adding and removing elements") {
            
            
            it("should add elements") {
                let a: NSString! = NSString(string: "A")
                var weakSet = WeakSet()
                
                weakSet.insert(a)
                expect(weakSet.strings) == [a]
                
                weakSet.remove(a!)
                expect(weakSet.strings) == []
                expect(weakSet.contains(a)) == false
            }
            
            
            it("should remove elements") {
                let a: NSString! = NSString(string: "A")
                let b: NSString! = NSString(string: "B")
                var weakSet = WeakSet(a, b)
                
                weakSet.remove(a)
                expect(weakSet.strings) == [b]
                expect(weakSet.contains(a)) == false
                
                weakSet.remove(b)
                expect(weakSet.strings) == []
                expect(weakSet.contains(b)) == false
            }
            
        }
        
        describe("generator") {
            
            it("should iterate over elements") {
                let a: NSString! = NSString(string: "A")
                let b: NSString! = NSString(string: "B")
                var i = 0
                let weakSet = WeakSet(a, b)
                for _ in weakSet {
                    i += 1
                }
                expect(Array(weakSet).count) == 2
            }
            
        }
        
        describe("references") {
            
            it("should be weak") {
                var a: NSString! = NSString(string: "A")
                var b: NSString! = NSString(string: "B")
                
                var weakSet = WeakSet(a, b)
                expect(Array(weakSet).count) == 2
                
                weakSet.insert(a)
                expect(Array(weakSet).count) == 2
                
                a = nil
                expect(Array(weakSet).count) == 1
                
                b = nil
                expect(Array(weakSet).count) == 0
            }
            
        }
        
    }
    
}

extension NSString: WithID {
    var id: Int {
        return self.hashValue
    }
}

private extension WeakSet {
    var strings: [NSString] {
        return self.map { $0 as! NSString }
    }
}