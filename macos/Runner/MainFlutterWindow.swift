import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // The xib's 800x600 default is cramped for Melodize's mobile-shaped layout;
    // use the same default size as the Linux runner (linux/runner/my_application.cc).
    let windowFrame = NSRect(
      x: self.frame.origin.x,
      y: self.frame.origin.y,
      width: 1280,
      height: 720)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
