//
//  ImageView.swift
//  Kletka
//
//  Created by admin on 19.10.2026.
//

import UIKit

final class ImageView: UIView {

    var onMove: ((ImageItem) -> Void)?
    var onDelete: ((UUID) -> Void)?

    private var item: ImageItem
    private let imageView = UIImageView()
    private let deleteButton = UIButton(type: .system)
    private let border = UIView()

    private var dragStartFrame: CGRect = .zero
    private var dragStartPoint: CGPoint = .zero
    private var isActive = false

    init(item: ImageItem, image: UIImage) {
        self.item = item
        super.init(frame: item.frame)
        imageView.image = image
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        clipsToBounds = false
        layer.cornerRadius = 4

        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        border.frame = bounds
        border.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        border.layer.borderColor = UIColor.systemBlue.cgColor
        border.layer.borderWidth = 2
        border.layer.cornerRadius = 4
        border.isHidden = true
        border.isUserInteractionEnabled = false
        addSubview(border)

        deleteButton.setTitle("×", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.backgroundColor = UIColor.systemRed
        deleteButton.layer.cornerRadius = 14
        deleteButton.frame = CGRect(x: bounds.width - 20, y: -8, width: 28, height: 28)
        deleteButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        addSubview(deleteButton)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        addGestureRecognizer(longPress)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    func update(item: ImageItem) {
        self.item = item
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return isActive
    }

    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        isActive = true
        border.isHidden = false
        deleteButton.isHidden = false
        superview?.bringSubviewToFront(self)
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        if isActive {
            isActive = false
            border.isHidden = true
            deleteButton.isHidden = true
        }
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard isActive else { return }
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
            guard let board = superview as? BoardView else { return }
            let worldFrame = board.worldRect(from: frame)
            var i = item
            i.frame = worldFrame
            item = i
            onMove?(i)
        default:
            break
        }
    }

    @objc private func deleteTapped() {
        onDelete?(item.id)
    }
}
