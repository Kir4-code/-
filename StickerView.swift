import UIKit

final class StickerView: UIView {

    var onChange: ((Sticker) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onMove: ((Sticker) -> Void)?

    private var sticker: Sticker
    private let textView = UITextView()
    private let colorButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let bar = UIView()

    private var dragStartFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero

    init(sticker: Sticker) {
        self.sticker = sticker
        super.init(frame: sticker.frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        layer.cornerRadius = 3
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        bar.backgroundColor = UIColor.black.withAlphaComponent(0.08)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.isUserInteractionEnabled = true
        addSubview(bar)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        bar.addGestureRecognizer(pan)

        colorButton.translatesAutoresizingMaskIntoConstraints = false
        colorButton.addTarget(self, action: #selector(cycleColor), for: .touchUpInside)
        bar.addSubview(colorButton)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setTitle("×", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        deleteButton.setTitleColor(.black, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteSticker), for: .touchUpInside)
        bar.addSubview(deleteButton)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 15, weight: .medium)
        textView.textColor = UIColor(hex: "#1d2433")
        textView.delegate = self
        textView.isScrollEnabled = false
        addSubview(textView)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 26),

            colorButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 4),
            colorButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            colorButton.widthAnchor.constraint(equalToConstant: 22),
            colorButton.heightAnchor.constraint(equalToConstant: 22),

            deleteButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -4),
            deleteButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 22),
            deleteButton.heightAnchor.constraint(equalToConstant: 22),

            textView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        updateUI()
    }

    func update(sticker: Sticker) {
        self.sticker = sticker
        updateUI()
    }

    private func updateUI() {
        backgroundColor = UIColor(hex: sticker.color.hex)
        colorButton.backgroundColor = UIColor(hex: sticker.color.hex)
        colorButton.layer.cornerRadius = 11
        colorButton.layer.borderWidth = 1.5
        colorButton.layer.borderColor = UIColor.black.withAlphaComponent(0.5).cgColor
        if textView.text != sticker.text {
            textView.text = sticker.text
        }
    }

    @objc private func handleDrag(_ g: UIPanGestureRecognizer) {
        switch g.state {
        case .began:
            dragStartFrame = frame
            dragStartPoint = g.translation(in: superview)
            superview?.bringSubviewToFront(self)
        case .changed:
            let t = g.translation(in: superview)
            let dx = t.x - dragStartPoint.x
            let dy = t.y - dragStartPoint.y
            frame = dragStartFrame.offsetBy(dx: dx, dy: dy)
        case .ended, .cancelled:
            guard let board = superview as? BoardView else { break }
            let worldFrame = board.worldRect(from: frame)
            var s = sticker
            s.frame = worldFrame
            sticker = s
            onMove?(s)
        default:
            break
        }
    }

    @objc private func cycleColor() {
        let all = StickerColor.allCases
        let idx = all.firstIndex(of: sticker.color) ?? 0
        let next = all[(idx + 1) % all.count]
        var s = sticker
        s.color = next
        sticker = s
        updateUI()
        onChange?(s)
    }

    @objc private func deleteSticker() {
        onDelete?(sticker.id)
    }
}

extension StickerView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        var s = sticker
        s.text = textView.text
        sticker = s
        onChange?(s)
    }
}
