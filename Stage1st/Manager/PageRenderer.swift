//
//  PageRenderer.swift
//  Stage1st
//
//  Created by Zheng Li on 10/16/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Mustache
import KissXML
import CocoaLumberjack
import Reachability
import Crashlytics

protocol PageRenderer {
    var topic: S1Topic { get }

    func templateBundle() -> Bundle
    func userIsBlocked(with userID: UInt) -> Bool
    func generatePage(with floors: [Floor]) -> String
}

extension PageRenderer {
    func templateBundle() -> Bundle {
        let templateBundleURL = Bundle.main.url(forResource: "WebTemplate", withExtension: "bundle")!
        return Bundle(url: templateBundleURL)!
    }

    func userIsBlocked(with _: UInt) -> Bool {
        return false
    }

    func generatePage(with floors: [Floor]) -> String {
        do {
            let template = try Template(named: "html/thread",
                                        bundle: templateBundle(),
                                        templateExtension: "mustache",
                                        encoding: .utf8)
            let data = Box(pageData(with: floors, topic: topic))
            let result = try template.render(data)
            return result
        } catch let error {
            DDLogWarn("[PageRenderer] error: \(error)")
            return ""
        }
    }

    private func pageData(with floors: [Floor], topic: S1Topic) -> [String: Any] {
        func fontStyleFile() -> String {
            switch (UIDevice.current.userInterfaceIdiom, UserDefaults.standard.object(forKey: "FontSize") as? String) {
            case (.phone, .some("15px")):
                return "content_15px.css"
            case (.phone, .some("17px")):
                return "content_17px.css"
            case (.phone, .some("19px")):
                return "content_19px.css"
            case (.pad, .some("18px")):
                return "content_ipad_18px.css"
            case (.pad, .some("20px")):
                return "content_ipad_20px.css"
            case (.pad, .some("22px")):
                return "content_ipad_22px.css"
            default:
                return "content_15px.css"
            }
        }

        func colorStyle() -> [String: Any?] {
            return [
                "background": ColorManager.shared.htmlColorStringWithID("5"),
                "text": ColorManager.shared.htmlColorStringWithID("21"),
                "border": ColorManager.shared.htmlColorStringWithID("14"),
                "borderText": ColorManager.shared.htmlColorStringWithID("17"),
            ]
        }

        func floorsData() -> [[String: Any?]] {
            var isFirstInPage = true
            var data = [[String: Any?]]()
            for floor in floors {
                data.append(floorData(with: floor, topicAuthorID: topic.authorUserID.flatMap({ UInt(truncating: $0) }), isFirstInPage: isFirstInPage))
                isFirstInPage = false
            }
            return data
        }

        return [
            "font-style-file": fontStyleFile(),
            "color": colorStyle(),
            "floors": floorsData(),
        ]
    }

    // swiftlint:disable nesting
    private func floorData(with floor: Floor, topicAuthorID: UInt?, isFirstInPage: Bool) -> [String: Any?] {
        func processContent(content: String?) -> String {
            func stripTails(content: String) -> String {
                let mutableString = (content as NSString).mutableCopy() as! NSMutableString

                let brPattern0 = "(<br ?/>|<br>|<br></br>)*"
                let brPattern1 = "(<br ?/>(&#13;)?\\n)*"
                let pattern0 = brPattern0 + "<a href=\"misc\\.php\\?mod\\=mobile\"[^<]*?</a>"
                let pattern1 = brPattern1 + "( |&nbsp;)*(—+|-+) ?(来自|发送自|发自|from)[^<>]*?<a href[^>]*(stage1st-reader|s1-pluto|stage1\\.5j4m\\.com|S1Nyan|saralin|S1-Next|s1next)[^>]*>[^<]*?</a>[^<]*"
                let pattern2 = brPattern1 + "发自我的(iPhone|iPad) via <a href[^>]*saralin[^>]*>[^<]*?</a>"
                let pattern3 = brPattern1 + "(\u{A0}| |&nbsp;)*(—+|-+) ?(来自|发送自|发自) ?[^<>]*"
                S1Global.regexReplace(mutableString, matchPattern: pattern0, withTemplate: "")
                S1Global.regexReplace(mutableString, matchPattern: pattern1, withTemplate: "")
                S1Global.regexReplace(mutableString, matchPattern: pattern2, withTemplate: "")
                mutableString.s1_replace(pattern: pattern3, with: "")
                return mutableString as String
            }

            func process(HTMLString: String, with floorID: Int) -> String {
                func processImages(xmlDocument: DDXMLDocument) -> DDXMLDocument {
                    func isMahjongFaceImage(imageSourceString: String?) -> Bool {
                        if let srcString = imageSourceString, srcString.hasPrefix("http://static.saraba1st.com/image/smiley") {
                            return true
                        }
                        return false
                    }

                    guard let images = (try? xmlDocument.nodes(forXPath: "//img")) as? [DDXMLElement] else {
                        return xmlDocument
                    }

                    var imageIndexInCurrentFloor = 1
                    for image in images {
                        let srcString = image.attribute(forName: "src")?.stringValue
                        let fileString = image.attribute(forName: "file")?.stringValue

                        if let fileString = fileString {
                            image.removeAttribute(forName: "src")
                            image.addAttribute(withName: "src", stringValue: fileString)
                        } else if let srcString = srcString, !srcString.hasPrefix("http") {
                            image.removeAttribute(forName: "src")
                            image.addAttribute(withName: "src", stringValue: AppEnvironment.current.serverAddress.api + "/" + srcString)
                        }

                        if !isMahjongFaceImage(imageSourceString: srcString) {
                            if let finalImageSrcString = image.attribute(forName: "src")?.stringValue {
                                // Prepare new image element.
                                let imageElement = DDXMLElement(name: "img")
                                imageElement.addAttribute(withName: "id", stringValue: "\(floorID)-img\(imageIndexInCurrentFloor)")
                                imageIndexInCurrentFloor += 1
                                if UserDefaults.standard.bool(forKey: "Display") || MyAppDelegate.reachability.isReachableViaWiFi() {
                                    if #available(iOS 11.0, *) {
                                        let schemeChangedImageSrcString = finalImageSrcString
                                            .s1_replace(pattern: "^https", with: "images")
                                            .s1_replace(pattern: "^http", with: "image")
                                        imageElement.addAttribute(withName: "src", stringValue: schemeChangedImageSrcString)
                                    } else {
                                        imageElement.addAttribute(withName: "src", stringValue: finalImageSrcString)
                                    }

                                } else {
                                    let placeholderURLString = templateBundle().path(forResource: "Placeholder", ofType: "png", inDirectory: "image")!
                                    imageElement.addAttribute(withName: "src", stringValue: placeholderURLString)
                                }

                                // Transform original image element to link element.
                                let linkElement = image
                                linkElement.name = "a"
                                linkElement.removeAttribute(forName: "src")
                                linkElement.removeAttribute(forName: "href")
                                linkElement.addAttribute(withName: "href", stringValue: "javascript:void(0);")
                                linkElement.removeAttribute(forName: "onclick")
                                let id = (imageElement.attribute(forName: "id")?.stringValue)!
                                let linkString = "window.webkit.messageHandlers.stage1st.postMessage({'type': 'image', 'src': '\(finalImageSrcString)', 'id': '\(id)'})"
                                linkElement.addAttribute(withName: "onclick", stringValue: linkString)
                                linkElement.addChild(imageElement)
                            }
                        } else {
                            let mahjongFacePath = srcString!.replacingOccurrences(of: "http://static.saraba1st.com/image/smiley", with: Bundle.main.bundleURL.appendingPathComponent("Mahjong").absoluteString.replacingOccurrences(of: "file://", with: ""))
                            if FileManager.default.fileExists(atPath: mahjongFacePath) {
                                image.removeAttribute(forName: "src")
                                image.addAttribute(withName: "src", stringValue: mahjongFacePath)
                            } else {
                                Answers.logCustomEvent(withName: "MahjongFace Cache Miss v3", customAttributes: ["url": srcString!.replacingOccurrences(of: "http://static.saraba1st.com/image/smiley", with: "")])
                            }
                        }

                        // clean image's attribute (if it is not a mahjong face, it is the linkElement)
                        image.removeAttribute(forName: "onmouseover")
                        image.removeAttribute(forName: "file")
                        image.removeAttribute(forName: "id")
                        image.removeAttribute(forName: "lazyloadthumb")
                        image.removeAttribute(forName: "border")
                        image.removeAttribute(forName: "width")
                        image.removeAttribute(forName: "height")
                    }

                    return xmlDocument
                }

                func processSpoilers(xmlDocument: DDXMLDocument) -> DDXMLDocument {
                    let spoilerXpathList = [
                        "//font[@color='LemonChiffon']",
                        "//font[@color='Yellow']",
                        "//font[@color='#fffacd']",
                        "//font[@color='#FFFFCC']",
                        "//font[@color='White']",
                        "//font[@color='#ffffff']",
                        "//font[@color='Black' or @color='black' or @color='#000000']/font[@style='background-color:Black' or @style='background-color:black']",
                        "//font[@style='background-color:Black' or @style='background-color:black']/font[@color='Black' or @color='black' or @color='#000000']"
                    ]

                    let spoilers = spoilerXpathList
                        .map { (try? xmlDocument.nodes(forXPath: $0)) as? [DDXMLElement] }
                        .flatMap { $0 } /// [[T]?] -> [[T]]
                        .flatMap { $0 } /// [[T]] -> [T]

                    for spoilerElement in spoilers {
                        spoilerElement.removeAttribute(forName: "color")
                        spoilerElement.name = "div"
                        spoilerElement.addAttribute(withName: "style", stringValue: "display:none;")
                        let index = spoilerElement.index
                        if let parentElement = spoilerElement.parent as? DDXMLElement {
                            spoilerElement.detach()
                            parentElement.setOwner(xmlDocument)

                            let buttonElement = DDXMLElement(name: "input")
                            buttonElement.addAttribute(withName: "value", stringValue: "显示反白内容")
                            buttonElement.addAttribute(withName: "type", stringValue: "button")
                            buttonElement.addAttribute(withName: "style", stringValue: "width:80px;font-size:10px;margin:0px;padding:0px;")
                            buttonElement.addAttribute(withName: "onclick", stringValue: "var e = this.parentNode.getElementsByTagName('div')[0];e.style.display = '';e.style.border = '#aaa 1px solid';this.style.display = 'none';")

                            let containerElement = DDXMLElement(name: "div")
                            containerElement.addChild(buttonElement)
                            containerElement.addChild(spoilerElement)

                            parentElement.insertChild(containerElement, at: index)
                        }
                    }

                    return xmlDocument
                }

                func processIndents(xmlDocument: DDXMLDocument) -> DDXMLDocument {
                    if let paragraphs = (try? xmlDocument.nodes(forXPath: "//td[@class='t_f']//p[@style]")) as? [DDXMLElement] {
                        for paragraph in paragraphs {
                            paragraph.removeAttribute(forName: "style")
                        }
                    }
                    return xmlDocument
                }

                guard
                    let data = HTMLString.data(using: .utf8),
                    let xmlDocument = try? DDXMLDocument(data: data, options: 0) else {
                    DDLogWarn("[PageRenderer] failed to parse floor \(floorID)")
                    return HTMLString
                }

                let processes = [
                    processImages,
                    processSpoilers,
                    processIndents
                ]

                let processedDocument = processes.reduce(xmlDocument) { $1($0) }
                let processedString = processedDocument.xmlString(withOptions: UInt(DDXMLNodePrettyPrint)) as NSString
                let cuttedString = processedString.substring(with: NSRange(location: 183, length: processedString.length - 183 - 17))

                if cuttedString.count > 0 {
                    return cuttedString.replacingOccurrences(of: "<br></br>", with: "<br />")
                }

                DDLogError("[ContentViewModel] Fail to modify image: \(HTMLString)")
                return HTMLString
            }

            guard let content = content else {
                DDLogWarn("[PageRenderer] nil content in floor \(floor.ID)")
                return ""
            }
            let firstProcessedContent = process(HTMLString: content, with: floor.ID)
            let secondProcessedContent = UserDefaults.standard.bool(forKey: "RemoveTails") ? stripTails(content: firstProcessedContent) : firstProcessedContent
            return secondProcessedContent
        }

        func processAuthor(floor: Floor) -> String {
            if let topicAuthorID = topicAuthorID, topicAuthorID == floor.author.ID, let floorIndexMark = floor.indexMark, floorIndexMark != "楼主" {
                return "\(floor.author.name) (楼主)"
            }

            return floor.author.name
        }

        func processIndexMark(indexMark: String?) -> String {
            switch indexMark {
            case .none:
                return "N"
            case let .some(mark) where mark != "楼主":
                return "#\(mark)"
            default:
                return "楼主"
            }
        }

        func processAttachments(attachmentImageURLs: [String]?) -> [[String: String]]? {
            if #available(iOS 11.0, *) {
                return attachmentImageURLs.flatMap { (list: [String]) in
                    return list.map {
                        return [
                            "url": $0.s1_replace(pattern: "^https", with: "images").s1_replace(pattern: "^http", with: "image"),
                            "trueURL": $0,
                            "ID": UUID().uuidString
                        ]
                    }
                }
            } else {
                return attachmentImageURLs.flatMap { (list: [String]) in
                    return list.map {
                        return [
                            "url": $0,
                            "trueURL": $0,
                            "ID": UUID().uuidString
                        ]
                    }
                }
            }
        }

        return [
            "index-mark": processIndexMark(indexMark: floor.indexMark),
            "author-ID": floor.author.ID,
            "author-name": processAuthor(floor: floor),
            "post-time": floor.creationDate?.s1_gracefulDateTimeString() ?? "无日期",
            "ID": "\(floor.ID)",
            "poll": nil,
            "content": userIsBlocked(with: floor.author.ID) ? "<td class=\"t_f\"><div class=\"s1-alert\">该用户已被您屏蔽</i></td>" : processContent(content: floor.content),
            "attachments": processAttachments(attachmentImageURLs: floor.imageAttachmentURLStringList),
            "is-first": isFirstInPage,
        ]
    }

    // swiftlint:enable nesting
}