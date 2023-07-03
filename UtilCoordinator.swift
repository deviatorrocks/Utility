//
//  Copyright © 2021 UBS AG. All rights reserved.
//
import UIKit
class UtilCoordinatorEvent {}
class UtilCoordinator {
	private let identifier: String = UUID().uuidString
	private(set) var children: Set<UtilCoordinator> = []
	private(set) weak var parent: UtilCoordinator?

	///  - important: Only one of ubsPresentingViewController or ubsPushingNavigationController can be set!
	/// The viewController to be presented on when we want to handle the coordinator modally
	/// Use ubsSetPresentingViewController(_:) to set the value!
	private(set) weak var ubsPresentingViewController: UIViewController?
	/// The navigationController to be pushed on when we want to handle the coordinator with push
	/// Use ubsSetPushingNavigationController(_:) to set the value!
	private(set) weak var ubsPushingNavigationController: UINavigationController?

	// The current lifecycle of the Coordinator
	private(set) var lifecycle: Lifecycle = .initial {
		willSet {
			assertLifecycle(against: newValue)
		}
	}

	deinit {
		assert(lifecycle != .started, "\(self) is still running, you are not allowed to deallocate me!")
	}

	/// Handles raised event from a child coordinator or propagated event from parent coordinator
	/// - important: This should return `false` if the event is not "consumed" by given coordinator.
	/// Otherwise it should return `true`.
	func handle(_ event: UtilCoordinatorEvent) -> Bool {
		return false
	}

	// MARK: - Event management
	/// Raises an `UBSCoordinatorEvent` to parent coordinator
	func raise(_ event: UtilCoordinatorEvent) {
		guard let parent else {
			// dlog("No parent coordinator to raise an event: \(event)", level: .assert)

			return
		}

		if !parent.handle(event) {
			parent.raise(event)
		}
	}

	/// Propagates an `UBSCoordinatorEvent` to all of its child coordinators
	func propagate(_ event: UtilCoordinatorEvent) {
		children.forEach { coordinator in
			if !coordinator.handle(event) {
				coordinator.propagate(event)
			}
		}
	}

	// MARK: - Child management
	/// Adds child coordinator and sets its parent value to `self`
	func add(child: UtilCoordinator) {
		precondition(child.parent == nil, "You are not allowed to add a coordinator with a parent.")
		if children.insert(child).inserted {
			child.parent = self
		}
	}

	/// Adds child coordinator and sets its parent value to  `nil`
	func remove(child: UtilCoordinator) {
		precondition(
			children.contains(child),
			"\(child) is not one of the children of \(self)")
		switch child.lifecycle {
		case .initial,
			.started:
			assertionFailure(
				"Coordinator in state \(child.lifecycle) is not allowed to be removed. "
					+ "Make sure you handle the coordinator state before removing it.")
		case .interrupted,
			.completed:
			break
		}

		if children.remove(child) != nil {
			child.parent = nil
		}
	}

	// MARK: - Lifecycle transition
	/// Start the coordinator.
	/// Starting a coordinator signals that the object should start to executing its tasks.
	/// Tasks include setting up / validating internal state, presenting view controllers or executing other controllers.
	/// All children will **not** be automatically started.
	func start() {
		let oldLifecycle = lifecycle
		lifecycle = .started
		parent?.childCoordinator(self, didChangeTo: .started, from: oldLifecycle)
	}

	/// Completes the coordinator.
	/// Completing a coordinator signals that the required task has been carried out by the coordinator successfully.
	/// All children will be automatically completed.
	func complete() {
		children.forEach { child in
			child.parent = nil
			child.complete()
		}
		let oldLifecycle = lifecycle
		lifecycle = .completed
		let parent = parent
		parent?.remove(child: self)
		parent?.childCoordinator(self, didChangeTo: .completed, from: oldLifecycle)
	}

	/// Interrupts the coordinator.
	/// Interrupting a coordinator signals that the assigned task was not
	/// carried out due to some failure (cancel button tapped, networking call failed).
	/// All children will be automatically interrupted.
	func interrupt() {
		children.forEach { child in
			child.parent = nil
			child.interrupt()
		}
		let oldLifecycle = lifecycle
		lifecycle = .interrupted
		let parent = parent
		parent?.remove(child: self)
		parent?.childCoordinator(self, didChangeTo: .interrupted, from: oldLifecycle)
	}

	/// Observe lifecycle changes in direct children coordinators.
	/// On initialisation the `initial` state change is ignored.
	/// - Parameters:
	///   - coordinator: The coordinator that changed it's lifecycle.
	///   - newState: The new lifecycle the coordinator is currently changed too.
	///   - oldState: The old lifecycle the coordinator changed from to the new state.
	func childCoordinator(
		_ coordinator: UtilCoordinator,
		didChangeTo newLifecycle: Lifecycle,
		from oldLifecycle: Lifecycle
	) {}
}

extension UtilCoordinator: Hashable {
	public static func == (lhs: UtilCoordinator, rhs: UtilCoordinator) -> Bool {
		return lhs.identifier == rhs.identifier
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(identifier)
	}
}

// MARK: - Lifecycle
extension UtilCoordinator {
	enum Lifecycle: Equatable, CaseIterable {
		// Initial Lifecycle of the Coordinator.
		case initial
		// The Coordinator has been started and ready to execute tasks.
		case started
		// The Coordinator has successfully executed all its tasks.
		case completed
		// The Coordinator has encountered an unrecoverable error while executing its tasks.
		case interrupted

		static let allAllowedLifecycleTransitions: [Lifecycle: Set<Lifecycle>] = [
			.initial: [.started, .interrupted],
			.started: [.completed, .interrupted],
			.interrupted: [],
			.completed: [.started],
		]
	}

	private func assertLifecycle(against newLifecycle: Lifecycle) {
		guard let allowedLifecycles = Lifecycle.allAllowedLifecycleTransitions[lifecycle] else {
			fatalError("\(type(of: self)) is in an unsupported lifecycle: \(lifecycle)")
		}
		assert(
			allowedLifecycles.contains(newLifecycle),
			"\(type(of: self)) is not allowed to transit from \(lifecycle) to \(newLifecycle)")
	}
}

// MARK: - Presentation handling
extension UtilCoordinator {
	func ubsSetPresentingViewController(_ viewController: UIViewController) {
		assert(
			ubsPresentingViewController == nil,
			"ubsPresentingViewController is only allowed to be set once.")
		assert(
			ubsPushingNavigationController == nil,
			"ubsPresentingViewController is not allowed to be set when ubsPushingNavigationController is set.")
		ubsPresentingViewController = viewController
	}

	func ubsSetPushingNavigationController(_ navigationController: UINavigationController) {
		assert(
			ubsPresentingViewController == nil,
			"ubsPushingNavigationController is not allowed to be set when ubsPresentingViewController is set")
		assert(
			ubsPushingNavigationController == nil,
			"ubsPushingNavigationController is only allowed to be set once.")
		ubsPushingNavigationController = navigationController
	}

	/// Should be used to show the first viewController in the coordinator, either modally or pushed, ideally from the start function.
	func show(
		viewController: UIViewController,
		animated: Bool,
		onBeforePush: ((UIViewController) -> UIViewController)? = nil,
		onBeforePresent: ((UIViewController) -> UIViewController)? = nil,
		completion: (() -> Void)? = nil
	) {
		if let ubsPresentingViewController {
			let viewController = onBeforePresent?(viewController) ?? viewController
			ubsPresentingViewController.present(viewController, animated: animated, completion: completion)
		} else if let ubsPushingNavigationController {
			let viewController = onBeforePush?(viewController) ?? viewController
			ubsPushingNavigationController.utilPushViewController(
				viewController, animated: animated, completion: completion)
		} else {
			// dlog("No present or push is possible, invalid coordinator configuration.", level: .assert)
		}
	}

	/// Should be used to hide the first viewController in the coordinator either by dismissing or by popping, ideally before or during the complete function.
	func hide(animated: Bool, completion: (() -> Void)? = nil) {
		if let ubsPresentingViewController {
			ubsPresentingViewController.dismiss(animated: animated, completion: completion)
		} else if let ubsPushingNavigationController {
			ubsPushingNavigationController.utilPopViewController(animated: animated, completion: completion)
		} else {
			// dlog("No dismiss or pop is possible, invalid coordinator configuration.", level: .assert)
		}
	}
}

// MARK: Print Tree
#if DEBUG
extension UtilCoordinator {
	func debugTree() {
		var coordinator = self
		while let parent = coordinator.parent {
			coordinator = parent
		}
		if self === coordinator {
			// dlog("\(type(of: coordinator))📍", level: .debug, domain: .coordinator)
		} else {
			// dlog("\(type(of: coordinator))", level: .debug, domain: .coordinator)
		}
		printTreeRecursively(from: coordinator, level: 0)
	}

	private func printTreeRecursively(from parent: UtilCoordinator, level: Int) {
		for coordinator in parent.children {
			var base = ""
			for _ in 0...level {
				base += "    "
			}
			if self === coordinator {
				// dlog("\(base)\(type(of: coordinator))📍", level: .debug, domain: .coordinator)
			} else {
				// dlog("\(base)\(type(of: coordinator))", level: .debug, domain: .coordinator)
			}
			printTreeRecursively(from: coordinator, level: level + 1)
		}
	}
}
#endif
