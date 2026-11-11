import CoreGraphics
import Testing
@testable import TextFlash

// MARK: - AX 写入结果快照
// 覆盖“AX 返回成功但内容未落地”的判定逻辑，避免误判导致重复写入。

@Test func snapshotConfirmsChangeWhenCharacterCountGrows() {
    let before = EventController.AXInsertionSnapshot(characterCount: 10, selectedRange: CFRange(location: 10, length: 0))
    let after = EventController.AXInsertionSnapshot(characterCount: 16, selectedRange: CFRange(location: 16, length: 0))

    #expect(after.confirmsChange(from: before))
}

@Test func snapshotConfirmsChangeWhenSelectedRangeMoves() {
    let before = EventController.AXInsertionSnapshot(characterCount: 12, selectedRange: CFRange(location: 9, length: 3))
    let after = EventController.AXInsertionSnapshot(characterCount: 12, selectedRange: CFRange(location: 9, length: 0))

    #expect(after.confirmsChange(from: before))
}

@Test func snapshotDoesNotConfirmChangeWhenNothingMoved() {
    let before = EventController.AXInsertionSnapshot(characterCount: 12, selectedRange: CFRange(location: 9, length: 3))
    let after = EventController.AXInsertionSnapshot(characterCount: 12, selectedRange: CFRange(location: 9, length: 3))

    #expect(!after.confirmsChange(from: before))
}

@Test func snapshotOnlyObservesAvailableSignals() {
    let countOnly = EventController.AXInsertionSnapshot(characterCount: 4, selectedRange: nil)
    let rangeOnly = EventController.AXInsertionSnapshot(characterCount: nil, selectedRange: CFRange(location: 2, length: 0))
    let empty = EventController.AXInsertionSnapshot(characterCount: nil, selectedRange: nil)

    #expect(countOnly.isObservable)
    #expect(rangeOnly.isObservable)
    #expect(!empty.isObservable)

    // 同一种信号保持不变时不认为写入生效
    #expect(!countOnly.confirmsChange(from: EventController.AXInsertionSnapshot(characterCount: 4, selectedRange: nil)))

    // 读数从可用变为不可用：无法证明未写入，按生效处理
    #expect(empty.confirmsChange(from: countOnly))
    #expect(countOnly.confirmsChange(from: rangeOnly))
}
