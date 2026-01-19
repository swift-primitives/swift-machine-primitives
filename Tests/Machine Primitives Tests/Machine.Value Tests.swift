import Testing
@testable import Machine_Primitives

@Suite("Machine.Value")
struct MachineValueTests {
    typealias Value = Machine.Value<Machine.Capture.Mode.Reference>

    @Test("make stores value with correct type")
    func makeStoresValue() {
        let value = Value.make(42)
        let extracted = value.take(Int.self)
        #expect(extracted == 42)
    }

    @Test("make works with String")
    func makeWithString() {
        let value = Value.make("hello")
        let extracted = value.take(String.self)
        #expect(extracted == "hello")
    }

    @Test("make works with custom struct")
    func makeWithCustomStruct() {
        struct Point: Sendable { var x: Int; var y: Int }
        let point = Point(x: 10, y: 20)
        let value = Value.make(point)
        let extracted = value.take(Point.self)
        #expect(extracted?.x == 10)
        #expect(extracted?.y == 20)
    }

    @Test("take returns nil for wrong type")
    func takeReturnsNilForWrongType() {
        let value = Value.make(42)
        let extracted = value.take(String.self)
        #expect(extracted == nil)
    }

    @Test("take returns nil for similar but different types")
    func takeReturnsNilForSimilarTypes() {
        let value = Value.make(Int32(42))
        let extracted = value.take(Int.self)
        #expect(extracted == nil)
    }

    @Test("unsafeTake extracts correct type")
    func unsafeTakeExtractsCorrectType() {
        let value = Value.make(99.5)
        let extracted = value.unsafeTake(Double.self)
        #expect(extracted == 99.5)
    }

    @Test("make preserves array values")
    func makePreservesArray() {
        let array = [1, 2, 3, 4, 5]
        let value = Value.make(array)
        let extracted = value.take([Int].self)
        #expect(extracted == array)
    }

    @Test("make preserves optional values")
    func makePreservesOptional() {
        let optional: Int? = 42
        let value = Value.make(optional)
        let extracted = value.take(Int?.self)
        #expect(extracted == optional)
    }

    @Test("make preserves nil optional")
    func makePreservesNilOptional() {
        let optional: Int? = nil
        let value = Value.make(optional)
        let extracted = value.take(Int?.self)
        #expect(extracted! == nil)
    }

    @Test("make works with tuple")
    func makeWithTuple() {
        let tuple = (1, "two", 3.0)
        let value = Value.make(tuple)
        let extracted = value.take((Int, String, Double).self)
        #expect(extracted?.0 == 1)
        #expect(extracted?.1 == "two")
        #expect(extracted?.2 == 3.0)
    }

    @Test("multiple values are independent")
    func multipleValuesIndependent() {
        let value1 = Value.make(1)
        let value2 = Value.make(2)
        let value3 = Value.make("three")

        #expect(value1.take(Int.self) == 1)
        #expect(value2.take(Int.self) == 2)
        #expect(value3.take(String.self) == "three")
    }
}
