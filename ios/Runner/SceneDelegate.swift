import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

}

/// NFR-20: a stray swipe from a screen edge does not leave the game (iOS
/// asks for a second swipe), and the home indicator hides while playing.
/// Main.storyboard uses this class for the Flutter view.
class GameViewController: FlutterViewController {
  override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
    .all
  }

  override var prefersHomeIndicatorAutoHidden: Bool {
    true
  }
}
