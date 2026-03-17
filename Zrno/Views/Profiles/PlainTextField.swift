import SwiftUI
import UIKit

/// A UIKit-backed text field that doesn't trigger SwiftUI's keyboard avoidance.
/// Looks and behaves like a native text field but doesn't push sheet content around.
/// The entire frame is tappable to focus.
struct PlainTextField: UIViewRepresentable {
    var placeholder: String
    @Binding var text: String
    var font: UIFont = .monospacedSystemFont(ofSize: 15, weight: .regular)
    var textColor: UIColor = .white
    var placeholderColor: UIColor = .gray
    var keyboardType: UIKeyboardType = .default
    var textAlignment: NSTextAlignment = .left

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = font
        field.textColor = textColor
        field.keyboardType = keyboardType
        field.textAlignment = textAlignment
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor, .font: font]
        )
        field.setContentHuggingPriority(.required, for: .vertical)
        field.setContentCompressionResistancePriority(.required, for: .vertical)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        field.font = font
        field.textColor = textColor
        field.keyboardType = keyboardType
        field.textAlignment = textAlignment
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor, .font: font]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
