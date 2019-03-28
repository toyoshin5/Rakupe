//
//  BookViewController.swift
//  BookReader
//
//  Created by Kishikawa Katsumi on 2017/07/03.
//  Copyright © 2017 Kishikawa Katsumi. All rights reserved.
//

import UIKit
import PDFKit
import MessageUI
import UIKit.UIGestureRecognizerSubclass
import ARKit

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

class BookViewController: UIViewController, UIPopoverPresentationControllerDelegate, PDFViewDelegate, ActionMenuViewControllerDelegate, SearchViewControllerDelegate, ThumbnailGridViewControllerDelegate, OutlineViewControllerDelegate, BookmarkViewControllerDelegate,ARSCNViewDelegate {
    var pdfDocument: PDFDocument?

    @IBOutlet weak var sceneView: ARSCNView!
    
    @IBOutlet weak var pdfView: PDFView!
    
    @IBOutlet weak var pdfThumbnailViewContainer: UIView!
    @IBOutlet weak var pdfThumbnailView: PDFThumbnailView!
    @IBOutlet private weak var pdfThumbnailViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleLabelContainer: UIView!
    @IBOutlet weak var pageNumberLabel: UILabel!
    @IBOutlet weak var pageNumberLabelContainer: UIView!

    let tableOfContentsToggleSegmentedControl = UISegmentedControl(items: [#imageLiteral(resourceName: "Grid"), #imageLiteral(resourceName: "List"), #imageLiteral(resourceName: "Bookmark-N")])
    @IBOutlet weak var thumbnailGridViewConainer: UIView!
    @IBOutlet weak var outlineViewConainer: UIView!
    @IBOutlet weak var bookmarkViewConainer: UIView!
    @IBOutlet weak var trackingResetButton: UIButton!
    
    var pointer = UIView()
    var pointerEffect = UIView()
    var pointerOverFlow = UIView()
    var bookmarkButton: UIBarButtonItem!

    
    var searchNavigationController: UINavigationController?

    let barHideOnTapGestureRecognizer = UITapGestureRecognizer()
    let pdfViewGestureRecognizer = PDFViewGestureRecognizer()
    
    private let defaultConfiguration: ARFaceTrackingConfiguration = {
        let configuration = ARFaceTrackingConfiguration()
        return configuration
    }()
    
    //FeedBack
    private let heavyFeedbackGenerator: Any? = {
        if #available(iOS 10.0, *) {
            let generator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            generator.prepare()
            return generator
        } else {
            return nil
        }
    }()
    private let errorFeedbackGenerator: Any? = {
        if #available(iOS 10.0, *) {
            let generator: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()
            generator.prepare()
            return generator
        } else {
            return nil
        }
    }()

    //ViewDidload------------------------------------------
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(pdfViewPageChanged(_:)), name: .PDFViewPageChanged, object: nil)

        barHideOnTapGestureRecognizer.addTarget(self, action: #selector(gestureRecognizedToggleVisibility(_:)))
        view.addGestureRecognizer(barHideOnTapGestureRecognizer)

        tableOfContentsToggleSegmentedControl.selectedSegmentIndex = 0
        tableOfContentsToggleSegmentedControl.addTarget(self, action: #selector(toggleTableOfContentsView(_:)), for: .valueChanged)
        
        sceneView.delegate = self
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: [convertFromUIPageViewControllerOptionsKey(UIPageViewController.OptionsKey.interPageSpacing): 20])

        pdfView.addGestureRecognizer(pdfViewGestureRecognizer)

        pdfView.document = pdfDocument

        pdfThumbnailView.layoutMode = .horizontal
        pdfThumbnailView.pdfView = pdfView

        pointer.frame = CGRect(x: 100, y: 90, width: 20, height: 68)
        pointer.clipsToBounds = true
        pointer.layer.cornerRadius = 10
        pointer.backgroundColor = UIColor.red
        pointer.layer.borderColor = UIColor.white.cgColor
        pointer.layer.borderWidth = 2
        
        pointerEffect.frame = CGRect(x: 0, y: 90, width: 0, height: 68)
        pointerEffect.clipsToBounds = true
        pointerEffect.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        pointerEffect.isHidden = true
        
        pointerOverFlow.frame = CGRect(x: 0, y: 90, width: 0, height: 68)
        pointerOverFlow.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        pointerOverFlow.layer.cornerRadius = 34
        
        trackingResetButton.clipsToBounds = true
        trackingResetButton.layer.cornerRadius = 10
        titleLabel.text = pdfDocument?.documentAttributes?["Title"] as? String
        titleLabelContainer.layer.cornerRadius = 4
        pageNumberLabelContainer.layer.cornerRadius = 4
        
        
        
        resume()
        
        view.addSubview(pointerEffect)
        view.addSubview(pointerOverFlow)
        view.addSubview(pointer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.session.run(defaultConfiguration)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }
    

    @IBAction func trackingReset(_ sender: Any) {
        sceneView.session.run(defaultConfiguration, options: .resetTracking)
    }
    
    func heavyHaptic(){
        if #available(iOS 10.0, *), let generator = heavyFeedbackGenerator as? UIImpactFeedbackGenerator {
            generator.impactOccurred()
        }
    }
    func errorHaptic(){
        if #available(iOS 10.0, *), let generator = errorFeedbackGenerator as? UINotificationFeedbackGenerator {
            generator.notificationOccurred(.error)
        }
    }
    
    

    
    
   
    
    
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        adjustThumbnailViewHeight()
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) in
            self.adjustThumbnailViewHeight()
        }, completion: nil)
    }

    private func adjustThumbnailViewHeight() {
        self.pdfThumbnailViewHeightConstraint.constant = 44 + self.view.safeAreaInsets.bottom
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? ThumbnailGridViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? OutlineViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? BookmarkViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        }
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }

    func actionMenuViewControllerShareDocument(_ actionMenuViewController: ActionMenuViewController) {
        let mailComposeViewController = MFMailComposeViewController()
        if let lastPathComponent = pdfDocument?.documentURL?.lastPathComponent,
            let documentAttributes = pdfDocument?.documentAttributes,
            let attachmentData = pdfDocument?.dataRepresentation() {
            if let title = documentAttributes["Title"] as? String {
                mailComposeViewController.setSubject(title)
            }
            mailComposeViewController.addAttachmentData(attachmentData, mimeType: "application/pdf", fileName: lastPathComponent)
        }
    }

    func actionMenuViewControllerPrintDocument(_ actionMenuViewController: ActionMenuViewController) {
        let printInteractionController = UIPrintInteractionController.shared
        printInteractionController.printingItem = pdfDocument?.dataRepresentation()
        printInteractionController.present(animated: true, completionHandler: nil)
    }

    func searchViewController(_ searchViewController: SearchViewController, didSelectSearchResult selection: PDFSelection) {
        selection.color = .yellow
        pdfView.currentSelection = selection
        pdfView.go(to: selection)
        showBars()
    }

    func thumbnailGridViewController(_ thumbnailGridViewController: ThumbnailGridViewController, didSelectPage page: PDFPage) {
        resume()
        pdfView.go(to: page)
    }

    func outlineViewController(_ outlineViewController: OutlineViewController, didSelectOutlineAt destination: PDFDestination) {
        
        resume()
        pdfView.go(to: destination)
    }

    func bookmarkViewController(_ bookmarkViewController: BookmarkViewController, didSelectPage page: PDFPage) {
       
        resume()
        pdfView.go(to: page)
    }
    
    func setSpeed(overFlowWidth:Int)->Double{
        let speed:Double = Double(overFlowWidth)
        return speed
    }
    
    var pointerState = 0 //l,c,r:-,0,+(1000までカウント)
    var repeatCount = 0
    var speedOfCount = 1
    var endCheck = false
    //顔を検知したら通る-----------------------------------------------
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
      
        
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }
        let bias:CGFloat = -5
        let head_x = faceAnchor.transform.columns.2.x //顔の向き(rad)
        let head_degree_x = CGFloat(head_x.radiansToDegrees)+bias //顔の向き(degree)とカメラ位置による補正
        
    
        
        DispatchQueue.main.async {
            
            self.pointer.center.x = head_degree_x*30+UIScreen.main.bounds.width/2
            /*白いやつの幅*/
            let overFlowWidth = max(max(Int(self.pointer.center.x),Int(UIScreen.main.bounds.width))-Int(UIScreen.main.bounds.width),-min(Int(self.pointer.center.x),0))/2
            /*淡赤いやつの幅*/
            let effectWidth = Int(abs(self.pointerState)*Int(UIScreen.main.bounds.width)/2000)
            
            self.pointer.center.x = self.outCheck(x: self.pointer.center.x)
            /*淡赤いやつのゲージの進みやすさ*/
            
            self.speedOfCount = Int(self.setSpeed(overFlowWidth: overFlowWidth))
            print(overFlowWidth)
            if self.pointer.center.x == 0 {
                self.pointerState -= self.speedOfCount
                self.pointerEffect.isHidden = false
                self.pointerOverFlow.isHidden = false
                self.pointerEffect.frame = CGRect(x: 0, y: 90, width: effectWidth, height: 68)
                self.pointerOverFlow.frame = CGRect(x: 0, y: 90, width: overFlowWidth, height: 68)
                self.pointerOverFlow.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
            }else if self.pointer.center.x == UIScreen.main.bounds.width{
                self.pointerState += self.speedOfCount
                self.pointerEffect.isHidden = false
                self.pointerOverFlow.isHidden = false
                self.pointerEffect.frame = CGRect(x:Int(UIScreen.main.bounds.width)-effectWidth, y: 90, width: effectWidth, height: 68)
                self.pointerOverFlow.frame = CGRect(x:Int(UIScreen.main.bounds.width)-overFlowWidth, y: 90, width: overFlowWidth, height: 68)
                self.pointerOverFlow.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMinXMinYCorner]
            }else{
                self.pointerState = 0
                self.repeatCount = 0
                self.pointerEffect.isHidden = true
                self.pointerOverFlow.isHidden = true
                self.endCheck = false
            }
            
            if self.pointerState >= 2000{
                if self.pdfView.canGoToNextPage(){
                    self.pointerState = 0
                    self.pointerEffect.isHidden = true
                    self.repeatCount += 1
                    self.heavyHaptic()
                    self.pdfView.goToNextPage(nil)
                }else{
                    if self.endCheck == false{
                        self.errorHaptic()
                        self.endCheck = true
                    }
                }
            }else if self.pointerState <= -2000{
                if self.pdfView.canGoToPreviousPage(){
                    self.repeatCount += 1
                    self.pointerEffect.isHidden = true
                    self.pointerState = 0
                    self.heavyHaptic()
                    self.pdfView.goToPreviousPage(nil)
                }else{
                    if self.endCheck == false{
                        self.errorHaptic()
                        self.endCheck = true
                    }
                }
                
            }
        }
        
        
    
    }
    
    
   
    
    func outCheck(x:CGFloat)->CGFloat{
        return max(0,min(UIScreen.main.bounds.width,x))
    }
    private func resume() {
        let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Chevron"), style: .plain, target: self, action: #selector(back(_:)))
        let tableOfContentsButton = UIBarButtonItem(image: #imageLiteral(resourceName: "List"), style: .plain, target: self, action: #selector(showTableOfContents(_:)))
        let actionButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(showActionMenu(_:)))
        navigationItem.leftBarButtonItems = [backButton, tableOfContentsButton, actionButton]

        let brightnessButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Brightness"), style: .plain, target: self, action: #selector(showAppearanceMenu(_:)))
        let searchButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Search"), style: .plain, target: self, action: #selector(showSearchView(_:)))
        bookmarkButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Bookmark-N"), style: .plain, target: self, action: #selector(addOrRemoveBookmark(_:)))
        navigationItem.rightBarButtonItems = [bookmarkButton, searchButton, brightnessButton]

        pdfThumbnailViewContainer.alpha = 1

        pdfView.isHidden = false
        titleLabelContainer.alpha = 1
        pageNumberLabelContainer.alpha = 1
        thumbnailGridViewConainer.isHidden = true
        outlineViewConainer.isHidden = true

        barHideOnTapGestureRecognizer.isEnabled = true

        updateBookmarkStatus()
        updatePageNumberLabel()
    }
    
    private func showTableOfContents() {
        view.exchangeSubview(at: 0, withSubviewAt: 1)
        view.exchangeSubview(at: 0, withSubviewAt: 2)

        let backButton = UIBarButtonItem(image: #imageLiteral(resourceName: "Chevron"), style: .plain, target: self, action: #selector(back(_:)))
        let tableOfContentsToggleBarButton = UIBarButtonItem(customView: tableOfContentsToggleSegmentedControl)
        let resumeBarButton = UIBarButtonItem(title: NSLocalizedString("Resume", comment: ""), style: .plain, target: self, action: #selector(resume(_:)))
        navigationItem.leftBarButtonItems = [backButton, tableOfContentsToggleBarButton]
        navigationItem.rightBarButtonItems = [resumeBarButton]

        pdfThumbnailViewContainer.alpha = 0

        toggleTableOfContentsView(tableOfContentsToggleSegmentedControl)

        barHideOnTapGestureRecognizer.isEnabled = false
    }

    @objc func resume(_ sender: UIBarButtonItem) {
        resume()
    }

    @objc func back(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    @objc func showTableOfContents(_ sender: UIBarButtonItem) {
        showTableOfContents()
    }

    @objc func showActionMenu(_ sender: UIBarButtonItem) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: String(describing: ActionMenuViewController.self)) as? ActionMenuViewController {
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 300, height: 88)
            viewController.popoverPresentationController?.barButtonItem = sender
            viewController.popoverPresentationController?.permittedArrowDirections = .up
            viewController.popoverPresentationController?.delegate = self
            viewController.delegate = self
            present(viewController, animated: true, completion: nil)
        }
    }

    @objc func showAppearanceMenu(_ sender: UIBarButtonItem) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: String(describing: AppearanceViewController.self)) as? AppearanceViewController {
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 300, height: 44)
            viewController.popoverPresentationController?.barButtonItem = sender
            viewController.popoverPresentationController?.permittedArrowDirections = .up
            viewController.popoverPresentationController?.delegate = self
            present(viewController, animated: true, completion: nil)
        }
    }

    @objc func showSearchView(_ sender: UIBarButtonItem) {
        if let searchNavigationController = self.searchNavigationController {
            present(searchNavigationController, animated: true, completion: nil)
        } else if let navigationController = storyboard?.instantiateViewController(withIdentifier: String(describing: SearchViewController.self)) as? UINavigationController,
            let searchViewController = navigationController.topViewController as? SearchViewController {
            searchViewController.pdfDocument = pdfDocument
            searchViewController.delegate = self
            present(navigationController, animated: true, completion: nil)

            searchNavigationController = navigationController
        }
    }

    @objc func addOrRemoveBookmark(_ sender: UIBarButtonItem) {
        if let documentURL = pdfDocument?.documentURL?.absoluteString {
            var bookmarks = UserDefaults.standard.array(forKey: documentURL) as? [Int] ?? [Int]()
            if let currentPage = pdfView.currentPage,
                let pageIndex = pdfDocument?.index(for: currentPage) {
                if let index = bookmarks.index(of: pageIndex) {
                    bookmarks.remove(at: index)
                    UserDefaults.standard.set(bookmarks, forKey: documentURL)
                    bookmarkButton.image = #imageLiteral(resourceName: "Bookmark-N")
                } else {
                    UserDefaults.standard.set((bookmarks + [pageIndex]).sorted(), forKey: documentURL)
                    bookmarkButton.image = #imageLiteral(resourceName: "Bookmark-P")
                }
            }
        }
    }

    @objc func toggleTableOfContentsView(_ sender: UISegmentedControl) {
        pdfView.isHidden = true
        titleLabelContainer.alpha = 0
        pageNumberLabelContainer.alpha = 0

        if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 0 {
            thumbnailGridViewConainer.isHidden = false
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = true
        } else if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 1 {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = false
            bookmarkViewConainer.isHidden = true
        } else {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = false
        }
    }

    @objc func pdfViewPageChanged(_ notification: Notification) {
        if pdfViewGestureRecognizer.isTracking {
            hideBars()
        }
        updateBookmarkStatus()
        updatePageNumberLabel()
    }
    
    @objc func gestureRecognizedToggleVisibility(_ gestureRecognizer: UITapGestureRecognizer) {
        if let navigationController = navigationController {
            if navigationController.navigationBar.alpha > 0 {
                hideBars()
            } else {
                showBars()
            }
        }
    }

    private func updateBookmarkStatus() {
        if let documentURL = pdfDocument?.documentURL?.absoluteString,
            let bookmarks = UserDefaults.standard.array(forKey: documentURL) as? [Int],
            let currentPage = pdfView.currentPage,
            let index = pdfDocument?.index(for: currentPage) {
            bookmarkButton.image = bookmarks.contains(index) ? #imageLiteral(resourceName: "Bookmark-P") : #imageLiteral(resourceName: "Bookmark-N")
        }
    }

    private func updatePageNumberLabel() {
        if let currentPage = pdfView.currentPage, let index = pdfDocument?.index(for: currentPage), let pageCount = pdfDocument?.pageCount {
            pageNumberLabel.text = String(format: "%d/%d", index + 1, pageCount)
        } else {
            pageNumberLabel.text = nil
        }
    }

    private func showBars() {
        if let navigationController = navigationController {
            UIView.animate(withDuration: CATransaction.animationDuration()) {
                navigationController.navigationBar.alpha = 1
                self.pdfThumbnailViewContainer.alpha = 1
                self.titleLabelContainer.alpha = 1
                self.pageNumberLabelContainer.alpha = 1
            }
        }
    }

    private func hideBars() {
        if let navigationController = navigationController {
            UIView.animate(withDuration: CATransaction.animationDuration()) {
                navigationController.navigationBar.alpha = 0
                self.pdfThumbnailViewContainer.alpha = 0
                self.titleLabelContainer.alpha = 0
                self.pageNumberLabelContainer.alpha = 0
            }
        }
    }
}

class PDFViewGestureRecognizer: UIGestureRecognizer {
    var isTracking = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = false
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIPageViewControllerOptionsKey(_ input: UIPageViewController.OptionsKey) -> String {
	return input.rawValue
}
