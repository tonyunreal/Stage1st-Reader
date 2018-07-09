//
//  StripTailTests.swift
//  Stage1stTests
//
//  Created by Zheng Li on 2018/7/9.
//  Copyright © 2018 Renaissance. All rights reserved.
//

import Foundation
import XCTest
@testable import Stage1st

class StripTailTests: XCTestCase {
    class Stripper: PageRenderer {
        var topic: S1Topic

        init(topic: S1Topic) { self.topic = topic }
    }

    let stripper = Stripper(topic: S1Topic(topicID: 0))

    func testStripS1NextGooseTail() {
        let input = """
        Test<br />
        <br />
        —— 來自 OnePlus ONEPLUS A3010, Android 8.0.0上的 <a href="https://github.com/ykrank/S1-Next/releases" target="_blank">S1Next-鵝版</a> v2.0-play</td>
        """
        let expectedOutput = """
        Test</td>
        """
        XCTAssertEqual(stripper.stripTails(content: input), expectedOutput)
    }

    func testStripS1NextGooseTail2() {
        let input = """
        Test<br />
        <br />
        — from samsung SM-G930F, Android 8.0.0 of <a href="https://pan.baidu.com/s/1mi43uRm" target="_blank">S1 Next Goose</a> v2.0-play</td>
        """
        let expectedOutput = """
        Test</td>
        """
        XCTAssertEqual(stripper.stripTails(content: input), expectedOutput)
    }

    func testStripOfficialTail1() {
        let input = """
        Test<br />
        <br />
        <a href="https://www.coolapk.com/apk/140634" target="_blank"><font color="#999999">  -- 来自 有消息提醒的 Stage1官方 Android客户端</font></a></td>
        """
        let expectedOutput = """
        Test</td>
        """
        XCTAssertEqual(stripper.stripTails(content: input), expectedOutput)
    }
}
