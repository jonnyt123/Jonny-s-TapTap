import UIKit

enum GameCenterPresenter {
    static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let windowScene = scenes.first
        let keyWindow = windowScene?.windows.first { $0.isKeyWindow } ?? windowScene?.windows.first
        let root = keyWindow?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }

    static func present(_ vc: UIViewController) {
        DispatchQueue.main.async {
            guard let top = topMostViewController() else {
                print("GC Presenter: no top view controller")
                return
            }
            top.present(vc, animated: true)
        }
    }
}
