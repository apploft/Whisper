import UIKit

public enum WhisperAction: String {
  case present = "Whisper.PresentNotification"
  case show = "Whisper.ShowNotification"
}

let whisperFactory: WhisperFactory = WhisperFactory()

open class WhisperFactory: NSObject {

  struct AnimationTiming {
    static let movement: TimeInterval = 0.3
    static let switcher: TimeInterval = 0.1
    static let popUp: TimeInterval = 1.5
    static let loaderDuration: TimeInterval = 0.7
    static let totalDelay: TimeInterval = popUp + movement * 2
  }

  weak var navigationController: UINavigationController?
  var edgeInsetHeight: CGFloat = 0
  var whisperView: WhisperView!
  var delayTimer = Timer()
  var presentTimer = Timer()
  var navigationStackCount = 0

    var navigationBarFrameObserver: NSKeyValueObservation?
    var isUpdating: Bool = false

  // MARK: - Initializers

  public override init() {
    super.init()
    WindowFrameObserver.shared.startObserving()
    
    if #available(iOS 11.0, *) {
        
    } else {
        NotificationCenter.default.addObserver(self, selector: #selector(WhisperFactory.orientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(WhisperFactory.orientationDidChange), name: NSNotification.Name(rawValue: Notifications.windowFrameChanged), object: nil)
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public func craft(_ message: Message, navigationController: UINavigationController, action: WhisperAction) {
    self.navigationController = navigationController
    self.navigationController?.delegate = self
    presentTimer.invalidate()

    var containsWhisper = false
    for subview in navigationController.navigationBar.subviews {
      if let whisper = subview as? WhisperView {
        whisperView = whisper
        containsWhisper = true
        break
      }
    }

    if !containsWhisper {
      whisperView = WhisperView(height: navigationController.navigationBar.frame.height, message: message)
      whisperView.frame.size.height = 0
      var maximumY = navigationController.navigationBar.frame.height

      whisperView.transformViews.forEach {
        $0.frame.origin.y = -10
        $0.alpha = 0
      }
        
        if #available(iOS 11.0, *) {
            if let searchBar = navigationController.visibleViewController?.navigationItem.searchController?.searchBar {
                maximumY += searchBar.frame.size.height
            }
        } else {
            for subview in navigationController.navigationBar.subviews {
                if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
            }
        }

      whisperView.frame.origin.y = maximumY
      whisperView.frame.size.width = navigationController.view.bounds.size.width
      whisperView.autoresizingMask = .flexibleWidth
      navigationController.navigationBar.addSubview(whisperView)
        
        if #available(iOS 11.0, *) {
            navigationBarFrameObserver = navigationController.navigationBar.observe(\.frame, changeHandler: { (_, value) in
                self.orientationDidChange()
            })
        }
    }

    if containsWhisper {
      changeView(message, action: action)
    } else {
      switch action {
      case .present:
        presentView()
      case .show:
        showView()
      }
    }
  }

  public func silentWhisper(_ controller: UINavigationController, after: TimeInterval) {
    self.navigationController = controller
    guard let navigationController = self.navigationController else { return }
    
    var whisperSubview: WhisperView? = nil
    for subview in navigationController.navigationBar.subviews {
      if let whisper = subview as? WhisperView {
        whisperSubview = whisper
        break
      }
    }

    if whisperSubview == nil {
        return
    }

    whisperView = whisperSubview
    delayTimer.invalidate()
    delayTimer = Timer.scheduledTimer(timeInterval: after, target: self,
      selector: #selector(WhisperFactory.delayFired(_:)), userInfo: nil, repeats: false)
  }

  // MARK: - Presentation

  func presentView() {
    moveControllerViews(true)

    UIView.animate(withDuration: AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = WhisperView.Dimensions.height
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = 0

        if subview == self.whisperView.complementImageView {
          subview.frame.origin.y = (WhisperView.Dimensions.height - WhisperView.Dimensions.imageSize) / 2
        }

        subview.alpha = 1
      }
    })
  }

  func showView() {
    moveControllerViews(true)

    UIView.animate(withDuration: AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = WhisperView.Dimensions.height
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = 0

        if subview == self.whisperView.complementImageView {
          subview.frame.origin.y = (WhisperView.Dimensions.height - WhisperView.Dimensions.imageSize) / 2
        }

        subview.alpha = 1
      }
      }, completion: { _ in
        self.delayTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self,
          selector: #selector(WhisperFactory.delayFired(_:)), userInfo: nil, repeats: false)
    })
  }

  func changeView(_ message: Message, action: WhisperAction) {
    presentTimer.invalidate()
    delayTimer.invalidate()
    hideView()

    let title = message.title
    let textColor = message.textColor
    let backgroundColor = message.backgroundColor
    let action = action.rawValue

    var array = ["title": title, "textColor" : textColor, "backgroundColor": backgroundColor, "action": action] as [String : Any]
    if let images = message.images { array["images"] = images }

    presentTimer = Timer.scheduledTimer(timeInterval: AnimationTiming.movement * 1.1, target: self,
      selector: #selector(WhisperFactory.presentFired(_:)), userInfo: array, repeats: false)
  }

  func hideView() {
    moveControllerViews(false)
    
    UIView.animate(withDuration: AnimationTiming.movement, animations: {
      self.whisperView.frame.size.height = 0
      for subview in self.whisperView.transformViews {
        subview.frame.origin.y = -10
        subview.alpha = 0
      }
      }, completion: { _ in
        self.whisperView.removeFromSuperview()
        self.isUpdating = false
    })
  }

  // MARK: - Timer methods

  @objc func delayFired(_ timer: Timer) {
    hideView()
  }

  @objc func presentFired(_ timer: Timer) {
    guard let navigationController = self.navigationController,
      let userInfo = timer.userInfo as? [String : AnyObject],
      let title = userInfo["title"] as? String,
      let textColor = userInfo["textColor"] as? UIColor,
      let backgroundColor = userInfo["backgroundColor"] as? UIColor,
      let actionString = userInfo["action"] as? String else { return }

    var images: [UIImage]? = nil

    if let imageArray = userInfo["images"] as? [UIImage]? { images = imageArray }

    let action = WhisperAction(rawValue: actionString)
    let message = Message(title: title, textColor: textColor, backgroundColor: backgroundColor, images: images)

    whisperView = WhisperView(height: navigationController.navigationBar.frame.height, message: message)
    whisperView.autoresizingMask = .flexibleWidth
    navigationController.navigationBar.addSubview(whisperView)
    whisperView.frame.size.height = 0

    var maximumY = navigationController.navigationBar.frame.height
    
    if #available(iOS 11.0, *) {
        if let searchBar = navigationController.visibleViewController?.navigationItem.searchController?.searchBar {
            maximumY += searchBar.frame.size.height
        }
    } else {
        for subview in navigationController.navigationBar.subviews {
            if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
        }
    }

    whisperView.frame.origin.y = maximumY

    action == .present ? presentView() : showView()
  }

  // MARK: - Animations

  func moveControllerViews(_ down: Bool) {
    guard let navigationController = self.navigationController,
        let visibleController = navigationController.visibleViewController
      , Config.modifyInset
      else { return }

    let stackCount = navigationController.viewControllers.count

    if down {
      navigationStackCount = stackCount
    } else if navigationStackCount != stackCount {
      return
    }

    if !(edgeInsetHeight == WhisperView.Dimensions.height && down) {
      edgeInsetHeight = down ? WhisperView.Dimensions.height : -WhisperView.Dimensions.height

      UIView.animate(withDuration: AnimationTiming.movement, animations: {
        self.performControllerMove(visibleController)
      })
    }
  }

  func performControllerMove(_ viewController: UIViewController) {
    guard Config.modifyInset else { return }

    if let tableView = viewController.view as? UITableView
      , viewController is UITableViewController {
        tableView.contentInset = UIEdgeInsetsMake(tableView.contentInset.top + edgeInsetHeight, tableView.contentInset.left, tableView.contentInset.bottom, tableView.contentInset.right)
    } else if let collectionView = viewController.view as? UICollectionView
      , viewController is UICollectionViewController {
        collectionView.contentInset = UIEdgeInsetsMake(collectionView.contentInset.top + edgeInsetHeight, collectionView.contentInset.left, collectionView.contentInset.bottom, collectionView.contentInset.right)
    } else {
      for view in viewController.view.subviews {
        if let scrollView = view as? UIScrollView {
          scrollView.contentInset = UIEdgeInsetsMake(scrollView.contentInset.top + edgeInsetHeight, scrollView.contentInset.left, scrollView.contentInset.bottom, scrollView.contentInset.right)
        }
      }
    }
  }

  // MARK: - Handling screen orientation

  @objc func orientationDidChange() {
    
    guard let whisper = whisperView, isUpdating == false else {return}
    
    whisper.isHidden = true
    whisper.frame.size.height = 0
    for subview in self.whisperView.transformViews {
        subview.frame.origin.y = -10
        subview.alpha = 0
    }
    
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: { [weak self] in
        guard let navigationController = self?.navigationController else {
            self?.isUpdating = false
            return
        }
        for subview in navigationController.navigationBar.subviews {
            guard let whisper = subview as? WhisperView else { continue }
            
            self?.isUpdating = true
            
            whisper.isHidden = false
            
            var maximumY = navigationController.navigationBar.frame.height
            
            if #available(iOS 11.0, *) {
                if let searchBar = navigationController.visibleViewController?.navigationItem.searchController?.searchBar {
                    maximumY += searchBar.frame.size.height
                }
            } else {
                for subview in navigationController.navigationBar.subviews where subview != whisper {
                    if subview.frame.maxY > maximumY && subview.frame.height > 0 { maximumY = subview.frame.maxY }
                }
            }
            
            whisper.frame = CGRect(
                x: whisper.frame.origin.x,
                y: maximumY,
                width: navigationController.navigationBar.bounds.size.width,
                height: whisper.frame.size.height)
            whisper.setupFrames()
            
            UIView.animate(withDuration: 0.2, animations: {
                whisper.frame.size.height = WhisperView.Dimensions.height
                for subview in whisper.transformViews {
                    subview.frame.origin.y = 0
                    
                    if subview == whisper.complementImageView {
                        subview.frame.origin.y = (WhisperView.Dimensions.height - WhisperView.Dimensions.imageSize) / 2
                    }
                    
                    subview.alpha = 1
                }
            }, completion: { _ in
                self?.isUpdating = false
            })
        }
        })
    }
}

// MARK: UINavigationControllerDelegate

extension WhisperFactory: UINavigationControllerDelegate {

  public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
    var maximumY = navigationController.navigationBar.frame.maxY - UIApplication.shared.statusBarFrame.height

    for subview in navigationController.navigationBar.subviews {
      if subview is WhisperView { navigationController.navigationBar.bringSubview(toFront: subview) }
        
        if #available(iOS 11.0, *) {
            if let searchBar = navigationController.visibleViewController?.navigationItem.searchController?.searchBar {
                maximumY += searchBar.frame.size.height
            }
        } else {
            if subview.frame.maxY > maximumY && !(subview is WhisperView) {
                maximumY = subview.frame.maxY
            }
        }
    }

    whisperView.frame.origin.y = maximumY
  }

  public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {

    for subview in navigationController.navigationBar.subviews where subview is WhisperView {
      moveControllerViews(true)

      if let index = navigationController.viewControllers.index(of: viewController) , index > 0 {
        edgeInsetHeight = -WhisperView.Dimensions.height
        performControllerMove(navigationController.viewControllers[Int(index) - 1])
        break
      }
    }
  }
}
