//
//  Created by Anastasiya Gorban on 4/14/15.
//  Copyright (c) 2015 Yalantis. All rights reserved.
//
//  Licensed under the MIT license: http://opensource.org/licenses/MIT
//  Latest version can be found at https://github.com/Yalantis/PullToRefresh
//

import UIKit
import Foundation

public protocol RefreshViewAnimator {
  func animateState(state: State)
}

// MARK: PullToRefresh

public class PullToRefresh: NSObject {
  
  public var hideDelay: NSTimeInterval = 0
  public var refreshing: Bool = false
  
  let refreshView: UIView
  var action: (() -> ())?
  
  private let animator: RefreshViewAnimator
  
  // MARK: - ScrollView & Observing
  
  private var scrollViewDefaultInsets = UIEdgeInsetsZero
  weak var scrollView: UIScrollView? {
    willSet {
      removeScrollViewObserving()
    }
    didSet {
      if let scrollView = scrollView {
        scrollViewDefaultInsets = scrollView.contentInset
        addScrollViewObserving()
      }
    }
  }
  
  private func addScrollViewObserving() {
    scrollView?.addObserver(self, forKeyPath: contentOffsetKeyPath, options: .Initial, context: &KVOContext)
  }
  
  private func removeScrollViewObserving() {
    scrollView?.removeObserver(self, forKeyPath: contentOffsetKeyPath, context: &KVOContext)
  }
  
  // MARK: - State
  
  var dragging: Bool? {
    didSet {
      if state == .Loading && dragging == false && oldValue == true {
        if let scrollView = scrollView {
          scrollView.contentOffset = previousScrollViewOffset
          scrollView.bounces = false
          UIView.animateWithDuration(0.3, delay: 0.0, options: [.BeginFromCurrentState, .AllowUserInteraction], animations: {
            let insets = self.refreshView.frame.height + self.scrollViewDefaultInsets.top
            scrollView.contentInset.top = insets
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, -insets)
            }, completion: { finished in
              scrollView.bounces = true
          })
          
          action?()
        }
      } else if state == .Finished && dragging == false && oldValue == true {
        handleFinished()
      }
    }
  }
  
  var state: State = .Inital {
    didSet {
      animator.animateState(state)
      refreshing = state == .Loading
      switch state {
      case .Finished:
        if dragging == false {
          self.handleFinished()
        }
      default: break
      }
    }
  }
  
  // MARK: - Initialization
  
  public init(refreshView: UIView, animator: RefreshViewAnimator) {
    self.refreshView = refreshView
    self.animator = animator
  }
  
  deinit {
    removeScrollViewObserving()
  }
  
  // MARK: KVO
  
  private var KVOContext = "PullToRefreshKVOContext"
  private let contentOffsetKeyPath = "contentOffset"
  private var previousScrollViewOffset: CGPoint = CGPointZero
  
  override public func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<()>) {
    dragging = scrollView?.dragging
    if (context == &KVOContext && keyPath == contentOffsetKeyPath && object as? UIScrollView == scrollView) {
      let offset = previousScrollViewOffset.y + scrollViewDefaultInsets.top
      let refreshViewHeight = refreshView.frame.size.height
      
      
      switch offset {
      case 0 where (state != .Loading): state = .Inital
      case -refreshViewHeight...0 where (state != .Loading && state != .Finished):
        state = .Releasing(progress: -offset / refreshViewHeight)
      case -1000...(-refreshViewHeight):
        if state == State.Releasing(progress: 1) && state != State.Loading && dragging! {
          state = .Loading
        } else if state != State.Loading && state != State.Finished {
          state = .Releasing(progress: 1)
        }
      default: break
      }
    } else {
      super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
    }
    
    previousScrollViewOffset.y = scrollView!.contentOffset.y
  }
  
  // MARK: - Start/End Refreshing
  
  func startRefreshing() {
    if self.state != State.Inital {
      return
    }
    
    scrollView?.setContentOffset(CGPointMake(0, -refreshView.frame.height - scrollViewDefaultInsets.top), animated: true)
    let delayTime = dispatch_time(DISPATCH_TIME_NOW,
      Int64(0.27 * Double(NSEC_PER_SEC)))
    
    dispatch_after(delayTime, dispatch_get_main_queue(), {
      self.state = State.Loading
    })
  }
  
  func endRefreshing() {
    if state == .Loading {
      state = .Finished
    }
  }
  
  func handleFinished() {
    removeScrollViewObserving()
    UIView.animateWithDuration(0.7, delay: hideDelay, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.7, options: [.CurveEaseOut, .BeginFromCurrentState, .AllowUserInteraction], animations: {
      self.scrollView?.contentInset = self.scrollViewDefaultInsets
      self.scrollView?.contentOffset.y = -self.scrollViewDefaultInsets.top
      }, completion: { finished in
        self.addScrollViewObserving()
        self.state = .Inital
    })
  }
}

// MARK: - State enumeration

public enum State:Equatable, CustomStringConvertible {
  case Inital, Loading, Finished
  case Releasing(progress: CGFloat)
  
  public var description: String {
    switch self {
    case .Inital: return "Inital"
    case .Releasing(let progress): return "Releasing:\(progress)"
    case .Loading: return "Loading"
    case .Finished: return "Finished"
    }
  }
}

public func ==(a: State, b: State) -> Bool {
  switch (a, b) {
  case (.Inital, .Inital): return true
  case (.Loading, .Loading): return true
  case (.Finished, .Finished): return true
  case (.Releasing, .Releasing): return true
  default: return false
  }
}
