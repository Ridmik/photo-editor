//
//  ViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit
import AVFoundation

public final class MediaEditorViewController: UIViewController {
    
    /** holding the 2 imageViews original image and drawing & stickers */
    @IBOutlet weak var canvasView: UIView!
    //To hold the image
    @IBOutlet weak var imageView: UIImageView!
    //To hold the drawings and stickers
    @IBOutlet weak var canvasImageView: UIImageView!
    @IBOutlet weak var videoPlayerView: VideoPlayer!
    @IBOutlet weak var trimmerContainerView: UIView!
    @IBOutlet weak var trimDurationLabel: UILabel!
    @IBOutlet weak var trimmerView: TrimmerView!
    
    @IBOutlet weak var topToolbar: UIView!
    @IBOutlet weak var bottomToolbar: UIView!

    @IBOutlet weak var topGradient: UIView!
    @IBOutlet weak var bottomGradient: UIView!
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var colorPickerView: UIView!
    @IBOutlet weak var colorPickerViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var activityIndicatorContainerView: UIView!
    
    //Controls
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var trimButton: UIButton!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var drawButton: UIButton!
    @IBOutlet weak var markerButton: UIButton!
    @IBOutlet weak var volumeButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var continueIconButton: UIButton!
    @IBOutlet weak var continueImageLabelButtonView: RoundedCornerView!
    @IBOutlet weak var continueButtonImageView: CircularImageView!
    @IBOutlet weak var continueButtonLabel: UILabel!
    
    // MARK:- Public properties
    /// Array of Stickers `UIImage` that the user will choose from
    public var stickers : [UIImage] = []
    
    /// Array of Colors that will show while drawing or typing
    public var colors  : [UIColor] = []
    
    public var mediaEditorDelegate: MediaEditorDelegate?
    
    /// List of controls to be hidden
    public var hiddenControls : [Control] = []
    
    // MARK:- Internal properties
    var media: Media!
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    var stickersViewController: StickersViewController!
    var continueButtonStyle: ContinueButtonStyle!
    
    var stickersVCIsVisible = false
    var drawColor: UIColor = UIColor.black
    var drawColorInitial = UIColor.black
    var textColor: UIColor = UIColor.white
    var isDrawing: Bool = false
    var lastPoint: CGPoint!
    var swiped = false
    var lastPanPoint: CGPoint?
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    var isTyping: Bool = false
    /// Use this property for hiding contols for image or video editing by default without explicit setting from outside unlike `hiddenControls` property
    var defaultHiddenControls: [Control] = []
    var isAudioMuted = false {
        didSet {
            queuePlayer.isMuted = isAudioMuted
            volumeButton.isSelected = isAudioMuted
        }
    }
    
    private let queuePlayer = AVQueuePlayer()
    private var playerLooper: AVPlayerLooper?
    private var playbackTimer: Timer?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public static func makeForImage(_ image: UIImage, continueButtonStyle: ContinueButtonStyle = .icon) -> MediaEditorViewController {
        let editor = UIStoryboard(name: "Editor", bundle: Bundle(for: self)).instantiateInitialViewController() as! MediaEditorViewController
        editor.media = .photo(image)
        editor.defaultHiddenControls = [.trim, .volume]
        editor.continueButtonStyle = continueButtonStyle
        return editor
    }
    
    public static func makeForVideo(_ url: URL, continueButtonStyle: ContinueButtonStyle = .icon) -> MediaEditorViewController {
        let editor = UIStoryboard(name: "Editor", bundle: Bundle(for: self)).instantiateInitialViewController() as! MediaEditorViewController
        editor.media = .video(url)
        editor.defaultHiddenControls = [.crop, .marker]
        editor.continueButtonStyle = continueButtonStyle
        return editor
    }
    
    //Register Custom font before we load XIB
    public override func loadView() {
        registerFont()
        super.loadView()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if case .photo(let image) = self.media {
            self.setImageView(image: image)
        } else if case .video(let url) = self.media {
            let asset = AVURLAsset(url: url)
            let item = AVPlayerItem(asset: asset)
            playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            videoPlayerView.player = queuePlayer
            trimmerView.delegate = self
        }
        
        deleteView.layer.cornerRadius = deleteView.bounds.height / 2
        deleteView.layer.borderWidth = 2.0
        deleteView.layer.borderColor = UIColor.white.cgColor
        deleteView.clipsToBounds = true
        
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped))
        edgePan.edges = .bottom
        edgePan.delegate = self
        self.view.addGestureRecognizer(edgePan)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow),
                                               name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self,selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        
        configureCollectionView()
        stickersViewController = StickersViewController(nibName: "StickersViewController", bundle: Bundle(for: StickersViewController.self))
        hideControls()
        setupContinueButton()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if case .video(_) = self.media {
            queuePlayer.play()
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if case .video(_) = self.media {
            queuePlayer.pause()
            stopPlaybackPeriodicObserver()
        }
    }
    
    func configureCollectionView() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        colorsCollectionView.collectionViewLayout = layout
        colorsCollectionViewDelegate = ColorsCollectionViewDelegate()
        colorsCollectionViewDelegate.colorDelegate = self
        if !colors.isEmpty {
            colorsCollectionViewDelegate.colors = colors
        }
        colorsCollectionView.delegate = colorsCollectionViewDelegate
        colorsCollectionView.dataSource = colorsCollectionViewDelegate
        
        colorsCollectionView.register(
            UINib(nibName: "ColorCollectionViewCell", bundle: Bundle(for: ColorCollectionViewCell.self)),
            forCellWithReuseIdentifier: "ColorCollectionViewCell")
    }
    
    func setImageView(image: UIImage) {
        imageView.image = image
    }
    
    func hideToolbar(hide: Bool) {
        topToolbar.isHidden = hide
        topGradient.isHidden = hide
        bottomToolbar.isHidden = hide
        bottomGradient.isHidden = hide
    }
    
    private func startPlaybackPeriodicObserver() {
        // first stop the timer if previously running
        stopPlaybackPeriodicObserver()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            guard let startTime = self.trimmerView.startTime, let endTime = self.trimmerView.endTime else { return }
            
            let playbackTime = self.queuePlayer.currentTime()
            self.trimmerView.seek(to: playbackTime)
            
            if playbackTime >= endTime {
                self.queuePlayer.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                self.trimmerView.seek(to: startTime)
            }
        }
    }
    
    private func stopPlaybackPeriodicObserver() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    var trimmingDuration: String {
        let start = trimmerView.startTime ?? .zero
        let end = trimmerView.endTime ?? .zero
        let duration = (end - start).seconds.rounded()
        let integerDuration = Int(duration)
        return "\(integerDuration) sec"
    }
    
    
}

extension MediaEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing {
            self.drawColor = color
        } else if activeTextView != nil {
            activeTextView?.textColor = color
            textColor = color
        }
    }
}

extension MediaEditorViewController: TrimmerViewDelegate {
    
    public func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackPeriodicObserver()
        queuePlayer.pause()
        queuePlayer.seek(to: playerTime, toleranceBefore: .zero, toleranceAfter: .zero)
        trimDurationLabel.text = trimmingDuration
    }
    
    public func positionBarStoppedMoving(_ playerTime: CMTime) {
        queuePlayer.seek(to: playerTime, toleranceBefore: .zero, toleranceAfter: .zero)
        queuePlayer.play()
        startPlaybackPeriodicObserver()
    }
    
}

extension MediaEditorViewController {
    enum Media {
        case photo(UIImage)
        case video(URL)
    }
}
