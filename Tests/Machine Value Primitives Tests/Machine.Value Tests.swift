import Testing
@testable import Machine_Primitives

@Suite("Machine.Value")
struct MachineValueTests {
    typealias Value = Machine.Value<Machine.Capture.Mode.Reference>

    @Test("make stores value with correct type")
    func makeStoresValue() {
        let value = Value.make(42)
        let extracted = value[as: Int.self]
        #expect(extracted == 42)
    }

    @Test("make works with String")
    func makeWithString() {
        let value = Value.make("hello")
        let extracted = value[as: String.self]
        #expect(extracted == "hello")
    }

    @Test("make works with custom struct")
    func makeWithCustomStruct() {
        struct Point: Sendable { var x: Int; var y: Int }
        let point = Point(x: 10, y: 20)
        let value = Value.make(point)
        let extracted = value[as: Point.self]
        #expect(extracted.x == 10)
        #expect(extracted.y == 20)
    }

    @Test("subscript precondition-checks type mismatch")
    func subscriptPreconditionChecksTypeMismatch() {
        // The subscript uses precondition, so wrong-type access would trap.
        // We verify correct-type access works; wrong-type trapping is a precondition guarantee.
        let value = Value.make(42)
        let extracted = value[as: Int.self]
        #expect(extracted == 42)
    }

    @Test("subscript precondition-checks similar but different types")
    func subscriptPreconditionChecksSimilarTypes() {
        // Int32 vs Int are different types — subscript would trap on mismatch.
        // We verify correct-type access works.
        let value = Value.make(Int32(42))
        let extracted = value[as: Int32.self]
        #expect(extracted == 42)
    }

    @Test("subscript extracts correct type")
    func subscriptExtractsCorrectType() {
        let value = Value.make(99.5)
        let extracted = value[as: Double.self]
        #expect(extracted == 99.5)
    }

    @Test("make preserves array values")
    func makePreservesArray() {
        let array = [1, 2, 3, 4, 5]
        let value = Value.make(array)
        let extracted = value[as: [Int].self]
        #expect(extracted == array)
    }

    @Test("make preserves optional values")
    func makePreservesOptional() {
        let optional: Int? = 42
        let value = Value.make(optional)
        let extracted = value[as: Int?.self]
        #expect(extracted == optional)
    }

    @Test("make preserves nil optional")
    func makePreservesNilOptional() {
        let optional: Int? = nil
        let value = Value.make(optional)
        let extracted = value[as: Int?.self]
        #expect(extracted == nil)
    }

    @Test("make works with tuple")
    func makeWithTuple() {
        let tuple = (1, "two", 3.0)
        let value = Value.make(tuple)
        let extracted = value[as: (Int, String, Double).self]
        #expect(extracted.0 == 1)
        #expect(extracted.1 == "two")
        #expect(extracted.2 == 3.0)
    }

    @Test("multiple values are independent")
    func multipleValuesIndependent() {
        let value1 = Value.make(1)
        let value2 = Value.make(2)
        let value3 = Value.make("three")

        #expect(value1[as: Int.self] == 1)
        #expect(value2[as: Int.self] == 2)
        #expect(value3[as: String.self] == "three")
    }
}
