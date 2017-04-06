//
//  APPullToActionController.swift
//  Stage1st
//
//  Created by Zheng Li on 6/22/15.
//  Copyright (c) 2015 Renaissance. All rights reserved.
//

import CocoaLumberjack

public struct OffsetRange {
    public enum BaseLine: Int {
        case top, bottom, left, right
    }

    let beginPosition: Double
    let endPosition: Double
    let baseLine: BaseLine

    func progress(for currentOffset: Double) -> Double {
        return (currentOffset - beginPosition) / (endPosition - beginPosition)
    }
}

// MARK: -
public class PullToActionController: NSObject {
    public weak var scrollView: UIScrollView?
    public weak var delegate: PullToActionDelagete?

    public var offset: CGPoint = .zero
    public var size: CGSize = .zero
    public var inset: UIEdgeInsets = .zero

    public var filterDuplicatedSizeEvent = false

    fileprivate var progressActions = [String: OffsetRange]()

    // MARK: -
    public init(scrollView: UIScrollView) {
        self.scrollView = scrollView

        super.init()

        scrollView.delegate = self
        scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        scrollView.addObserver(self, forKeyPath: "contentInset", options: .new, context: nil)
    }

    deinit {
        DDLogDebug("[PullToAction] deinit")
    }

    public func addObservation(withName name: String, baseLine: OffsetRange.BaseLine, beginPosition: Double, endPosition: Double) {
        progressActions.updateValue(OffsetRange(beginPosition: beginPosition, endPosition: endPosition, baseLine: baseLine), forKey: name)
    }

    public func removeObservation(withName name: String) {
        progressActions.removeValue(forKey: name)
    }

    public var observationNames: [String] {
        return Array(progressActions.keys)
    }

    public func stop() {
        scrollView?.removeObserver(self, forKeyPath: "contentOffset")
        scrollView?.removeObserver(self, forKeyPath: "contentSize")
        scrollView?.removeObserver(self, forKeyPath: "contentInset")
        scrollView?.delegate = nil
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            guard let changes = change,
                  let newOffsetValue = changes[.newKey] as? NSValue else {
                return
            }

            offset = newOffsetValue.cgPointValue

            var progress = [String: Double]()
            for (name, actionOffset) in progressActions {
                let progressValue = actionOffset.progress(for: currentOffset(relativeTo: actionOffset.baseLine))
                progress.updateValue(progressValue, forKey: name)
            }

            if let delegateFunction = delegate?.scrollViewContentOffsetProgress {
                delegateFunction(progress)
            }
//            DDLogVerbose("[PullToAction] contentOffset: \(self.offset)")
        }

        if keyPath == "contentSize" {
            guard let changes = change,
                  let newSizeValue = changes[.newKey] as? NSValue else {
                return
            }
            let oldSize = size

            size = newSizeValue.cgSizeValue

            if filterDuplicatedSizeEvent && abs(size.height - oldSize.height) < 0.01 && abs(size.width - oldSize.width) < 0.01 {
                return
            }

            DDLogVerbose("[PullToAction] contentSize:w: \(size.width) h:\(size.height)")
            delegate?.scrollViewContentSizeDidChange?(size)
        }

        if keyPath == "contentInset" {
            guard let changes = change,
                  let newInsetValue = changes[.newKey] as? NSValue else {
                return
            }

            inset = newInsetValue.uiEdgeInsetsValue
            DDLogVerbose("[PullToAction] inset: top: \(inset.top) bottom: \(inset.bottom)")
        }
    }

    private func currentOffset(relativeTo baseLine: OffsetRange.BaseLine) -> Double {
        guard let scrollView = self.scrollView else {
            return Double(0.0)
        }

        switch baseLine {
        case .top:
            return Double(offset.y)
        case .bottom:
            return Double(offset.y - max(size.height - scrollView.bounds.height, 0.0))
        case .left:
            return Double(offset.x)
        case .right:
            return Double(offset.x - max(size.width - scrollView.bounds.width, 0.0))
        }
    }
}

private let forwardingScrollViewDelegateMethods = [
    #selector(UIScrollViewDelegate.scrollViewDidScroll(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidZoom(_:)),
    #selector(UIScrollViewDelegate.scrollViewWillBeginDragging(_:)),
    #selector(UIScrollViewDelegate.scrollViewWillEndDragging(_:withVelocity:targetContentOffset:)),
//    #selector(UIScrollViewDelegate.scrollViewDidEndDragging(_:willDecelerate:)), // Implimented by PullToActionController
    #selector(UIScrollViewDelegate.scrollViewWillBeginDecelerating(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndDecelerating(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation(_:)),
    #selector(UIScrollViewDelegate.viewForZooming(in:)),
    #selector(UIScrollViewDelegate.scrollViewWillBeginZooming(_:with:)),
    #selector(UIScrollViewDelegate.scrollViewDidEndZooming(_:with:atScale:)),
    #selector(UIScrollViewDelegate.scrollViewShouldScrollToTop(_:)),
    #selector(UIScrollViewDelegate.scrollViewDidScrollToTop(_:))
]

// MARK: UIScrollViewDelegate
extension PullToActionController: UIScrollViewDelegate {
    public override func responds(to aSelector: Selector!) -> Bool {
        for aForwardingScrollViewDelegateMethod in forwardingScrollViewDelegateMethods where aSelector == aForwardingScrollViewDelegateMethod {
            return delegate?.responds(to: aSelector) ?? false
        }

        return super.responds(to: aSelector)
    }

    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        for aForwardingScrollViewDelegateMethod in forwardingScrollViewDelegateMethods where aSelector == aForwardingScrollViewDelegateMethod {
            return delegate
        }

        return super.forwardingTarget(for: aSelector)
    }

    // MARK: -
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //TODO: consider content inset
        let topOffset = offset.y
        if topOffset < 0.0 {
            DDLogDebug("[PullToAction] End dragging <- \(topOffset)")
            delegate?.scrollViewDidEndDraggingOutsideTopBound?(with: topOffset)
            return
        }

        let bottomOffset = offset.y + scrollView.bounds.height - size.height
        if bottomOffset > 0.0 {
            DDLogDebug("[PullToAction] End dragging -> \(bottomOffset)")
            delegate?.scrollViewDidEndDraggingOutsideBottomBound?(with: bottomOffset)
            return
        }
    }

}

// MARK: -
@objc public protocol PullToActionDelagete: UIScrollViewDelegate {
    @objc optional func scrollViewDidEndDraggingOutsideTopBound(with offset: CGFloat)
    @objc optional func scrollViewDidEndDraggingOutsideBottomBound(with offset: CGFloat)
    @objc optional func scrollViewContentSizeDidChange(_ contentSize: CGSize)
    @objc optional func scrollViewContentOffsetProgress(_ progress: [String: Double])
}
