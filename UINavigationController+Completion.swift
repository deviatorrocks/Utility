//
//  Copyright © 2020 UBS AG. All rights reserved.
//

import UIKit

extension UINavigationController {
	func utilPopViewController(animated: Bool, completion: (() -> Void)? = nil) {
		popViewController(animated: animated)
		transitionCoordinator?.animate(
			alongsideTransition: nil,
			completion: { _ in
				completion?()
			})
	}

	func utilPopToRootViewController(animated: Bool, completion: (() -> Void)? = nil) {
		popToRootViewController(animated: animated)
		transitionCoordinator?.animate(
			alongsideTransition: nil,
			completion: { _ in
				completion?()
			})
	}

	func utilPopToViewController(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
		popToViewController(viewController, animated: animated)
		transitionCoordinator?.animate(
			alongsideTransition: nil,
			completion: { _ in
				completion?()
			})
	}

	func utilPushViewController(
		_ viewController: UIViewController,
		hidesTabBar: Bool,
		animated: Bool,
		completion: (() -> Void)? = nil
	) {
		viewController.hidesBottomBarWhenPushed = hidesTabBar
		utilPushViewController(viewController, animated: animated, completion: completion)
	}

	func utilPushViewController(
		_ viewController: UIViewController,
		animated: Bool,
		completion: (() -> Void)? = nil
	) {
		pushViewController(viewController, animated: animated)
		transitionCoordinator?.animate(
			alongsideTransition: nil,
			completion: { _ in
				completion?()
			})
	}
}
