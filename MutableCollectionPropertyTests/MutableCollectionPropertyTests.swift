//
//  MutableCollectionPropertyTests.swift
//  MutableCollectionPropertyTests
//
//  Created by Pedro Pinera Buendia on 14/10/15.
//  Copyright © 2015 com.gitdo. All rights reserved.
//

import XCTest
import Quick
import Nimble
import ReactiveCocoa

@testable import MutableCollectionProperty

class MutableCollectionPropertyTests: QuickSpec {

    override func spec() {

        describe("initialization") {

            it("should properly update the value once initialized") {
                let array: [String] = ["test1, test2"]
                let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                expect(property.value) == array
            }
        }

        describe("updates") {

            context("full update") {

                it("should notify the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: { event in
                            switch event {
                            case .Next(_):
                                done()
                            default: break
                            }
                        }).start()
                        property.value = ["test2", "test3"]
                    })
                }

                it("should notify the changes producer with the replaced enum type") {
                    let array: [String] = ["test1", "test2"]
                    let newArray: [String] = ["test2", "test3"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: {
                        (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Replacement(let newValue):
                                    expect(newValue) == newArray
                                    expect(i) == 1
                                case .EndChange:
                                    done()
                                default: break
                                }
                                i++
                            default: break
                            }
                        }).start()
                        property.value = newArray
                    })
                }
            }

        }

        describe("deletion") {

            context("delete at a given index") {

                it("should notify the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: {
                        (done) -> Void in
                        property.producer.on(event: {
                            event in
                            switch event {
                            case .Next(let newValue):
                                expect(newValue) == ["test1"]
                                done()
                            default: break
                            }
                        }).start()
                        property.removeAtIndex(1)
                    })
                }

                it("should notify the changes producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: {
                        (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Deletion(let index, let element):
                                    expect(i) == 1
                                    expect(index) == 1
                                    expect(element) == "test2"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.removeAtIndex(1)
                    })
                }
            }
            
            context("deleting the last element", {
                
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                expect(change) == ["test1"]
                                done()
                            default: break
                            }
                        }).start()
                        property.removeLast()
                    })
                }
                
                it("should notify the deletion to the changes producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Deletion(let index, let element):
                                    expect(i) == 1
                                    expect(index) == 1
                                    expect(element) == "test2"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.removeLast()
                    })
                }
                
            })
            
            context("deleting the first element", {
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                expect(change) == ["test2"]
                                done()
                            default: break
                            }
                        }).start()
                        property.removeFirst()
                    })
                }
                
                it("should notify the deletion to the changes producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Deletion(let index, let element):
                                    expect(i) == 1
                                    expect(index) == 0
                                    expect(element) == "test1"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.removeFirst()
                    })
                }
            })
            
            context("remove all elements", {
                it("should notify the deletion to the main producer") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                expect(change) == []
                                done()
                            default: break
                            }
                        }).start()
                        property.removeAll()
                    })
                }
                
                it("should notify the deletion to the changes producer with the right type") {
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Deletion(let index, let element):
                                    expect(i) >= 1
                                    expect(index) == array.count - i
                                    expect(element) == "test\(array.count - (i-1))"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.removeAll()
                    })
                }
            })

        }
        
        context("adding elements") { () -> Void in
            
            context("appending elements individually", { () -> Void in
                
                it("should notify about the change to the main producer", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: { (event) in
                            switch event {
                            case .Next(let next):
                                expect(next) == ["test1", "test2", "test3"]
                                done()
                            default: break
                            }
                        }).start()
                        property.append("test3")
                    })
                })
                
                it("should notify the changes producer about the adition", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Addition(let index, let element):
                                    expect(i) == 1
                                    expect(index) == 2
                                    expect(element) == "test3"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.append("test3")
                    })
                })
                
            })
            
            context("appending elements from another array", { () -> Void in
                
                it("should notify about the change to the main producer", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: { (event) in
                            switch event {
                            case .Next(let next):
                                expect(next) == ["test1", "test2", "test3", "test4"]
                                done()
                            default: break
                            }
                        }).start()
                        property.appendContentsOf(["test3", "test4"])
                    })
                })
                
                it("should notify the changes producer about the adition", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Addition(let index, let element):
                                    expect(i) >= 1
                                    expect(index) == i+1
                                    expect(element) == "test\(i+2)"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.appendContentsOf(["test3", "test4"])
                    })
                })
                
            })
            
            context("inserting elements", { () -> Void in
                
                it("should notify about the change to the main producer", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: { (event) in
                            switch event {
                            case .Next(let next):
                                expect(next) == ["test0", "test1", "test2"]
                                done()
                            default: break
                            }
                        }).start()
                        property.insert("test0", atIndex: 0)
                    })
                })
                
                it("should notify the changes producer about the adition", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Insertion(let index, let element):
                                    expect(i) == 1
                                    expect(index) == 0
                                    expect(element) == "test0"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.insert("test0", atIndex: 0)
                    })
                })
                
            })
            
            context("replacing elements", { () -> Void in
                
                it("should notify about the change to the main producer", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        property.producer.on(event: { (event) in
                            switch event {
                            case .Next(let next):
                                expect(next) == ["test3", "test4"]
                                done()
                            default: break
                            }
                        }).start()
                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
                    })
                })
                
                it("should notify the changes producer about the adition", closure: { () -> () in
                    let array: [String] = ["test1", "test2"]
                    let property: MutableCollectionProperty<String> = MutableCollectionProperty(array)
                    waitUntil(action: { (done) -> Void in
                        var i: Int = 0
                        property.changes.on(event: {
                            event in
                            switch event {
                            case .Next(let change):
                                switch change {
                                case .StartChange:
                                    expect(i) == 0
                                case .Replaced(let index, let element):
                                    expect(i) >= 1
                                    expect(index) == i - 1
                                    expect(element) == "test\(index+3)"
                                case .EndChange:
                                    done()
                                default: break
                                }
                            default: break
                            }
                            i++
                        }).start()
                        property.replace(Range<Int>(start: 0, end: 1), with: ["test3", "test4"])
                    })
                })
                
            })
            
        }

    }

}
