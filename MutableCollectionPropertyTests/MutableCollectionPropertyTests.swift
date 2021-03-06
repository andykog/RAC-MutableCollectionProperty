import XCTest
import Quick
import Nimble
import ReactiveCocoa

@testable import MutableCollectionProperty

class TestSection: MutableCollectionProperty<String> {
    override init(_ a: [String]) {
        super.init(a)
    }
}

extension TestSection: Equatable {}
func ==(a: TestSection, b: TestSection) -> Bool {
    return a.value == b.value
}

class MutableCollectionPropertyTests: QuickSpec {

    override func spec() {

        describe("initialization") {
            it("should properly update the value once initialized") {
                let array: [String] = ["test1, test2"]
                let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                expect(property.value) == array
            }
        }

        describe("flat updates") {

            context("full update") {

                it("should notify the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test2", "test3"]
                            done()
                        }
                        property.value = ["test2", "test3"]
                    })
                }
                
                it("should notify the flatChanges producer with the right sequence of changes") {
                    let array:    [String] = ["test0", "test1", "test2",         "test3"             ]
                    let newArray: [String] = [         "test1", "test2-changed", "test3", "test4-new"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Composite(let changes) = change {
                                let indexes = changes.map({$0.index!})
                                let elements = changes.map({$0.oldElement ?? $0.newElement!})
                                let operations = changes.map({$0.operation!})
                                expect(indexes) == [0, 2, 1, 3]
                                expect(elements) == ["test0", "test2", "test2-changed", "test4-new"]
                                expect(operations) == [.Removal, .Removal, .Insertion, .Insertion]
                                done()
                            }
                        }
                        property.value = newArray
                    })
                }
                
                it("should continue notifying the deepChanges producer after full update") {
                    let initialValue = [TestSection(["test0"])]
                    let nextValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    property.value = nextValue
                    waitUntil(action: { done in
                        property.changes.startWithNext { change in
                            if case .Insert(let indexPath, let element) = change {
                                expect(indexPath) == [0, 0]
                                expect(element as? String) == "test0"
                                done()
                            }
                        }
                        property.insert("test0", atIndexPath: [0, 0])
                    })
                }

            }

        }

        describe("flat deletion") {

            context("delete at a given index") {

                it("should notify the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test1"]
                            done()
                        }
                        property.removeAtIndex(1)
                    })
                }

                it("should notify the flatChanges producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Remove(let index, let element) = change {
                                expect(index) == 1
                                expect(element) == "test2"
                                done()
                            }
                        }
                        property.removeAtIndex(1)
                    })
                }
            }
            
            context("deleting the last element", {
                
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test1"]
                            done()
                        }
                        property.removeLast()
                    })
                }
                
                it("should notify the deletion to the flatChanges producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Remove(let index, let element) = change {
                                expect(index) == 1
                                expect(element) == "test2"
                                done()
                            }
                        }
                        property.removeLast()
                    })
                }
                
            })
            
            context("deleting the first element", {
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test2"]
                            done()
                        }
                        property.removeFirst()
                    })
                }
                
                it("should notify the deletion to the flatChanges producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Remove(let index, let element) = change {
                                expect(index) == 0
                                expect(element) == "test1"
                                done()
                            }
                        }
                        property.removeFirst()
                    })
                }
            })
            
            context("remove all elements", {
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == []
                            done()
                        }
                        property.removeAll()
                    })
                }
                
                it("should notify the deletion to the flatChanges producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Composite(let changes) = change {
                                let indexes = changes.map({$0.index!})
                                let elements = changes.map({$0.oldElement!})
                                let operations = changes.map({$0.operation!})
                                expect(indexes) == [0, 1]
                                expect(elements) == ["test1", "test2"]
                                expect(operations) == [.Removal, .Removal]
                                done()
                            }
                        }
                        property.removeAll()
                    })
                }
            })
            
            context("update or insert with subscript", {
                
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test0", "test2"]
                            done()
                        }
                        property[0] = "test0"
                    })
                }
                
                it("should notify the changes producer with the update") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        
                        property.changes.take(1).startWithNext { change in
                            if case .Update(let indexPath, let oldElement, let newElement) = change {
                                expect(indexPath) == [0]
                                expect(oldElement as? String) == "test1"
                                expect(newElement as? String) == "test0"
                                done()
                            }
                        }
                        property[0] = "test0"
                    })
                }
                
                it("should notify the changes producer with the insertion") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        
                        property.changes.take(1).startWithNext { change in
                            if case .Insert(let indexPath, let newElement) = change {
                                expect(indexPath) == [2]
                                expect(newElement as? String) == "test0"
                                done()
                            }
                        }
                        property[2] = "test0"
                    })
                }

            })


        }
        
        describe("deep deletion") {
            
            context("delete at a given indexPath") {
                
                it("should notify the main producer") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: {
                        done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == []
                            done()
                        }
                        property.removeAtIndex(0)
                    })
                }
                
                it("should notify the deepChanges producer") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.changes.take(1).startWithNext { change in
                            if case .Remove(let indexPath, let element) = change {
                                expect(indexPath) == [0, 1]
                                expect(element as? String) == "test2"
                                done()
                            }
                        }
                        property.removeAtIndexPath([0, 1])
                    })
                }
            }
 
        }
        
        context("flat adding elements") {
            
            context("appending elements individually", { () -> Void in
                
                it("should notify about the change to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test1", "test2", "test3"]
                            done()
                        }
                        property.append("test3")
                    })
                }
                
                it("should notify the flatChanges producer about the adition") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Insert(let index, let element) = change {
                                expect(index) == 2
                                expect(element) == "test3"
                                done()
                            }
                        }
                        property.append("test3")
                    })
                }
                
            })
            
            context("appending elements from another array", {
                
                it("should notify about the change to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test1", "test2", "test3", "test4"]
                            done()
                        }
                        property.appendContentsOf(["test3", "test4"])
                    })
                }
                
                it("should notify the flatChanges producer about the adition") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Composite(let changes) = change {
                                let indexes = changes.map({$0.index!})
                                let elements = changes.map({$0.newElement!})
                                let operations = changes.map({$0.operation!})
                                expect(indexes) == [2, 3]
                                expect(elements) == ["test3", "test4"]
                                expect(operations) == [.Insertion, .Insertion]
                                done()
                            }
                        }
                        property.appendContentsOf(["test3", "test4"])
                    })
                }
                
            })
            
            context("inserting elements", {
                
                it("should notify about the change to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test0", "test1", "test2"]
                            done()
                        }
                        property.insert("test0", atIndex: 0)
                    })
                }
                
                it("should notify the flatChanges producer about the adition") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Insert(let index, let element) = change {
                                expect(index) == 0
                                expect(element) == "test0"
                                done()
                            }
                        }
                        property.insert("test0", atIndex: 0)
                    })
                }
                
            })
            
            context("replacing elements", {
                
                it("should notify about the change to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == ["test3", "test4"]
                            done()
                        }
                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
                    })
                }
                
                it("should notify the flatChanges producer about the adition") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { done in
                        property.flatChanges.take(1).startWithNext { change in
                            if case .Composite(let changes) = change {
                                let indexes = changes.map({$0.index!})
                                let oldElements = changes.map({$0.oldElement!})
                                let newElements = changes.map({$0.newElement!})
                                let operations = changes.map({$0.operation!})
                                expect(indexes) == [0, 1]
                                expect(oldElements) == ["test1", "test2"]
                                expect(newElements) == ["test3", "test4"]
                                expect(operations) == [.Update, .Update]
                                done()
                            }
                        }
                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
                    })
                }
                
            })
            
        }
        
        context("deep adding elements") {
            
            context("inserting elements", {
                
                it("should notify about the change to the main producer") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == [TestSection(["test0", "test1", "test2"])]
                            done()
                        }
                        property.insert("test0", atIndexPath: [0, 0])
                    })
                }
                
                it("should notify the deepChanges producer about the adition") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.changes.take(1).startWithNext { change in
                            if case .Insert(let indexPath, let element) = change {
                                expect(indexPath) == [0, 0]
                                expect(element as? String) == "test0"
                                done()
                            }
                        }
                        property.insert("test0", atIndexPath: [0, 0])
                    })
                }
                
            })
            
            context("replacing elements", {
                
                it("should notify about the change to the main producer") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == [TestSection(["test8", "test2"])]
                            done()
                        }
                        property.replace(elementAtIndexPath: [0, 0], withElement: "test8")
                    })
                }
                
                it("should notify the deepChanges producer about the adition") {
                    let initialValue = [TestSection(["test1", "test2"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.changes.take(1).startWithNext { change in
                            if case .Update(let indexPath, let oldElement, let newElement) = change {
                                expect(indexPath) == [0, 0]
                                expect(oldElement as? String) == "test1"
                                expect(newElement as? String) == "test0"
                                done()
                            }
                        }
                        property.replace(elementAtIndexPath: [0, 0], withElement: "test0")
                    })
                }
                
                
            })
            
            
            context("moving elements", {
                
                it("should notify about the change to the main producer") {
                    let initialValue = [TestSection(["test1", "test2", "test3", "test4"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.producer.take(1).startWithNext { newValue in
                            expect(newValue) == [TestSection(["test1", "test3", "test2", "test4"])]
                            done()
                        }
                        property.move(fromIndexPath: [0, 1], toIndexPath: [0, 2])
                    })
                }
                
                it("should notify the deepChanges producer about the adition") {
                    let initialValue = [TestSection(["test1", "test2", "test3", "test4"])]
                    let property = MutableCollectionProperty(initialValue)
                    waitUntil(action: { done in
                        property.changes.take(1).startWithNext { change in
                            if case .Composite(let changes) = change {
                                let indexPaths = changes.map({$0.indexPath!})
                                let elements = changes.map({$0.oldElement as? String ?? $0.newElement as! String})
                                let operations = changes.map({$0.operation!})
                                expect(indexPaths) == [[0, 1], [0, 2]]
                                expect(elements) == ["test2", "test2"]
                                expect(operations) == [.Removal, .Insertion]
                                done()
                            }
                        }
                        property.move(fromIndexPath: [0, 1], toIndexPath: [0, 2])
                    })
                }

                
            })


        }
        
    }

}
