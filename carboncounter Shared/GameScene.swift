import SpriteKit
import SwiftUI
import UIKit
import CoreLocation
import UserNotifications
import Foundation
import PassKit
import AuthenticationServices
import Stripe



class GameScene: SKScene, UITextFieldDelegate, CLLocationManagerDelegate {

    private var cachedLeaderboardPosition: Int?
    private var lastLeaderboardFetch: Date?
    var timer: Timer?
    fileprivate var label: SKLabelNode?
    fileprivate var spinnyNode: SKShapeNode?
    var progressLabel: UILabel!
    var enterCarLabel: SKLabelNode!
    var homeButton: UIButton!
    var welcome = SKLabelNode()
    var startScreen = true
    var getStarted = SKLabelNode()
    var carLabel = SKLabelNode()
    var progress = SKLabelNode()
    var drivingStatusLabel: SKLabelNode?
    var background = SKSpriteNode(imageNamed: "background")
    var logoImage: UIImageView!
    var carbonOffsetsPurchased: Int = 0
    var carbonOffsetPurchaseHostingController: UIHostingController<CarbonOffsetPurchaseView>?
    var paymentController: PKPaymentAuthorizationViewController?
    private let paymentHandler = PaymentHandler()
    @State private var allTimeEmissions: Int = 0
    var dailyCounter = 0
    var totalKg: Int!
    var resetButton: UIButton!
    var userFullName: String = "Default User"
    let nameTextField = UITextField()
    private var doneButton: UIButton?
    
    var userScore = 0
    var dayByDay: [DailyEmissions] = Array(repeating: DailyEmissions(carEmissions: 0, food: 0, energy: 0, goods: 0), count: 7)
    
    // Add property to track current day's emissions
    var currentDayEmissions: DailyEmissions {
        get {
            return DailyEmissions(
                carEmissions: dailyCarEmissions,
                food: FOOD,
                energy: ENERGY,
                goods: GOODS
            )
        }
    }
    var dailyCarEmissions = 0
    var weekByWeek = [0, 0, 0, 0, 0]
    var stackView: UIStackView!
    var previewWindows: [UIView] = []
    var ENERGY = 0
    var FOOD = 0
    var GOODS = 0
    private let locationTracker = LocationManager()
    var histogramHostingController: UIHostingController<HistogramView>?
    var pieChartHostingController: UIHostingController<PieChartView>?
    var profileHostingController: UIHostingController<ProfileView>?
    var ecotrack = SKLabelNode()
    var viewLeaderboardButton = UIButton(type: .system)
    var weeklyScore: Int = 0
    var offsetGrams: Int = UserDefaults.standard.integer(forKey: "offsetGrams")

    
    var myProgressButton = UIButton(type: .system)
    var myBadgesButton = UIButton(type: .system)
    var hostingController: UIHostingController<LeaderboardView>?
    
    var isAuthenticated = false
    
    
    // UIPickerView declarations
    var yearPickerView: UIPickerView!
    var makePickerView: UIPickerView!
    var modelPickerView: UIPickerView!
    
    // UIStackView declaration
    
    // Variables to store input
    var carYear: String = ""
    var carMake: String = ""
    var carModel: String = ""
    var emission: String = ""
    
    // UIButton declaration
    var confirmButton: UIButton!
    
    // Location Manager
    var locationManager: CLLocationManager!
    var customLocationManager: LocationManager!
    
    // Data for pickers
    var years = [String]()
    var makes = [String]()
    var models = [String]()
    var carData = [[String]]()
    var fullNameTextField : UITextField?

    
    // Leaderboard variables
    var leaderboardLabel: SKLabelNode!
    var CalculateduserEmissions: Int = 0
    var otherUserEmissions = [Int]()
    
    func startSignInWithAppleFlow() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    
    func setupResetButton() {
        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset Daily Data", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = .systemBlue
        resetButton.layer.cornerRadius = 8
        resetButton.addTarget(self, action: #selector(resetDailyData), for: .touchUpInside)
        if let view = self.view {
            view.addSubview(resetButton)
            resetButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                resetButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                resetButton.widthAnchor.constraint(equalToConstant: 150),
                resetButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }
    
    @objc func resetDailyData() {
        dailyCarEmissions = 0
        totalKg = 0
        // Reset today's emissions
        ENERGY = 0
        FOOD = 0
        GOODS = 0

        saveArrays()
        
        // Update the UI to reflect the changes

        
        // You might want to add other UI updates here
        
        print("Daily data reset")
    }
    
    
    func loadCSVFile() -> [[String]]? {
        guard let path = Bundle.main.path(forResource: "caremissionsreal", ofType: "csv") else {
            print("CSV file not found in app bundle.")
            return nil
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var result: [[String]] = []
            
            let rows = content.components(separatedBy: .newlines)
            for (index, row) in rows.enumerated() {
                // Only keep even-indexed rows (including 0)
                if index % 2 == 0 {
                    let columns = row.components(separatedBy: ",")
                    if !columns.isEmpty {
                        result.append(columns)
                    }
                }
            }
            
            // Filter out arrays with length 1
            result = result.filter { $0.count > 1 }
            
            print("CSV file successfully loaded from app bundle with odd indices removed and short arrays filtered")
            return result
        } catch {
            print("Error loading CSV file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func removeShortArrays() {
        carData = carData.filter { $0.count > 1 }
        
        print("Filtered carData: \(carData)")
    }
    


    func updateProfile() {
        print(allTimeEmissions)
        if let profileView = profileHostingController?.rootView as? ProfileView {
            let updatedProfileView = ProfileView(
                username: profileView.username,
                allTimeEmissions: self.allTimeEmissions, // Use the class property
                dailyEmissionsAverage: profileView.dailyEmissionsAverage,
                carDetails: profileView.carDetails,
                leaderboardPosition: profileView.leaderboardPosition,
                carbonCreditsPurchased: carbonOffsetsPurchased, totalKg: totalKg
            )
            profileHostingController?.rootView = updatedProfileView
        }
    }
    
    func start() {
        // Schedule the timer to check every minute
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(checkTime), userInfo: nil, repeats: true)
    }

    @objc func checkTime() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let currentTime = dateFormatter.string(from: Date())
        
        if currentTime == "21:30" {
            updateEnergyAfterDriving()
        }
        if currentTime == "00:00" {
            performMidnightTasks()
        }
    }
    
    override func didMove(to view: SKView) {

        loadArrays()
        setupMidnightTimer()
        start()
        startHourlyIncrement()
        updateWeeklyHistogram()
        hideAppleSignInButton()
        super.didMove(to: view)
        
        // Setup welcome and get started labels
        welcome.text = "Welcome to your personal carbon accountant"
        welcome.zPosition = 2
        welcome.fontSize = 16
        welcome.position = CGPoint(x: 0, y: 250)
        welcome.fontColor = SKColor.white
        welcome.fontName = "AvenirNext-Bold"
        addChild(welcome)
        
        StripeAPI.defaultPublishableKey = "pk_live_51Q9qgvIkPhKQ4Pu3bt6Dj2uXUEVHCX39Y4r9WmracCglvD1J52Ued55IbJR4i4WTRkqHRTViUAksYhV0cYUbdriX00LtKC7lPS"
        
        fullNameTextField = UITextField(frame: CGRect(x: (size.width - 280) / 2, y: size.height / 2 - 20, width: 280, height: 40))
        guard let fullNameTextField = fullNameTextField else { return }

        // Configure the text field
        fullNameTextField.placeholder = "Enter your full name"
        fullNameTextField.borderStyle = .roundedRect
        fullNameTextField.autocorrectionType = .no
        fullNameTextField.returnKeyType = .done
        fullNameTextField.delegate = self
        fullNameTextField.backgroundColor = UIColor.white
        fullNameTextField.isHidden = true
        view.addSubview(fullNameTextField)
        
        enterCarLabel = SKLabelNode(text: "Select your car")
        enterCarLabel.zPosition = 2
        enterCarLabel.fontSize = 30
        enterCarLabel.position = CGPoint(x: 0, y: 250)
        enterCarLabel.fontColor = SKColor.white
        enterCarLabel.fontName = "AvenirNext-Bold"
        enterCarLabel.isHidden = true
        addChild(enterCarLabel)

        
        doneButton = UIButton(frame: CGRect(x: (size.width - 100) / 2, y: 500, width: 100, height: 40))
        guard let doneButton = doneButton else { return }

        // Configure the button
        doneButton.setTitle("Done", for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.backgroundColor = .blue // Set button background color
        doneButton.layer.cornerRadius = 5 // Rounded corners
        doneButton.addTarget(self, action: #selector(doneButtonPressed), for: .touchUpInside)
        doneButton.isHidden = true
        view.addSubview(doneButton)
        
        if UserDefaults.standard.bool(forKey: "hourlyIncrementActive") {
            startHourlyIncrement()
        }
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        
        drivingStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        
        // Set up the label properties
        if let drivingStatusLabel = drivingStatusLabel {
            drivingStatusLabel.fontSize = 14
            drivingStatusLabel.fontColor = .white
            drivingStatusLabel.horizontalAlignmentMode = .right
            drivingStatusLabel.verticalAlignmentMode = .top
            drivingStatusLabel.zPosition = 100 // Ensure it's above other elements
            drivingStatusLabel.position = CGPoint(x: 0, y: 0)
            drivingStatusLabel.isHidden = true
            
            // Add the label to the scene
            //self.addChild(drivingStatusLabel)
        }
        
        getStarted.text = "Get Started"
        getStarted.fontSize = 40
        getStarted.position = CGPoint(x: 0, y: 0)
        getStarted.fontColor = SKColor.white
        getStarted.zPosition = 2
        getStarted.fontName = "AvenirNext-Bold"
        addChild(getStarted)


        
        ecotrack.text = "EcoTrack"
        ecotrack.fontSize = 30
        ecotrack.position = CGPoint(x:0, y:-350)
        ecotrack.fontColor = SKColor.white
        ecotrack.zPosition = 2
        ecotrack.fontName = "AvenirNext-Bold"
        addChild(ecotrack)
        
        background.zPosition = 1
        background.position = CGPoint(x: 0, y: 0)
        addChild(background)
        if let savedCarYear = UserDefaults.standard.string(forKey: "carYear"),
           let savedCarMake = UserDefaults.standard.string(forKey: "carMake"),
           let savedCarModel = UserDefaults.standard.string(forKey: "carModel") {
            // Use saved information
            carYear = savedCarYear
            carMake = savedCarMake
            carModel = savedCarModel
            
            // Show home page
            
            setupHomePage()
        } else {
            // No saved information, show the get started screen
            showGetStartedScreen()
        }
        
        if let csvData = loadCSVFile() {
            carData = csvData
            years = Array(Set(carData.map { $0[0] })).sorted()
            makes = Array(Set(carData.map { $0[1] })).sorted()
            models = Array(Set(carData.map { $0[2] })).sorted()
            
            print("Years: \(years)")
            print("Makes: \(makes)")
            print("Models: \(models)")
        } else {
            print("Failed to load CSV data")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleDrivingStatusChanged), name: .drivingStatusChanged, object: nil)

        let username = UserDefaults.standard.string(forKey: "username") ?? "User\(Int.random(in: 1000...9999))"
            createUser(username: username) { success in
                if success {
                    print("User created or already exists")
                    UserDefaults.standard.set(username, forKey: "username")
                } else {
                    print("Failed to create user")
                }
            }
        
        // Setup logo image
//        logoImage = UIImageView(image: UIImage(named: "EcoTracker"))
//        logoImage.contentMode = .scaleAspectFit
//        logoImage.translatesAutoresizingMaskIntoConstraints = false
//

        
        homeButton = UIButton(type: .system)

        view.addSubview(homeButton)
        NotificationCenter.default.addObserver(self, selector: #selector(drivingStatusChanged), name: .drivingStatusChanged, object: nil)


            
            // Add tap gesture recognizer to the image view

        
        
        carLabel = self.childNode(withName: "carquestion") as! SKLabelNode
        carLabel.isHidden = true
        
        loadCSVFile()
        
        // Initialize LocationManager
        customLocationManager = LocationManager()
        customLocationManager.delegate = self
        
        // Request notification permission and schedule daily notifications
        requestNotificationPermission()
        scheduleDailyNotification()
        
        // Check for saved car information
        if let savedCarYear = UserDefaults.standard.string(forKey: "carYear"),
           let savedCarMake = UserDefaults.standard.string(forKey: "carMake"),
           let savedCarModel = UserDefaults.standard.string(forKey: "carModel") {
            // Use saved information
            carYear = savedCarYear
            carMake = savedCarMake
            carModel = savedCarModel
        } else {
            // No saved information, show the get started screen
            showGetStartedScreen()
        }
        
        // Setup leaderboard label
        leaderboardLabel = SKLabelNode()
        leaderboardLabel.fontSize = 20
        leaderboardLabel.fontColor = SKColor.black
        leaderboardLabel.position = CGPoint(x: 0, y: 100)
        leaderboardLabel.isHidden = true
        leaderboardLabel.zPosition = 2
        addChild(leaderboardLabel)
        
        locationTracker.delegate = self
 // Load GPX data
        locationTracker.startTrackingDriving()

        // Load GPX file


    }

    
//SETUP METHODS----------------------------------
    
    func showGetStartedScreen() {
        // Show the welcome and get started labels
        welcome.isHidden = false
        getStarted.isHidden = false
        
        // Remove any existing Apple ID button
        view?.viewWithTag(100)?.removeFromSuperview()
    }
    
    @objc func getStartedTapped() {
        welcome.isHidden = true
        getStarted.isHidden = true
        
        // Show Apple ID sign-in button
        if !isAuthenticated {
            startSignInWithAppleFlow()
            showAppleSignInButton()
        }

    }
    
    @objc func doneButtonPressed() {
        guard let name = fullNameTextField?.text, !name.isEmpty else {
            print("No name entered")
            return
        }
        // Handle what happens when the done button is pressed
        doneButton?.isHidden = true
        fullNameTextField?.isHidden = true
        setupHomePage()
        
        // Save the name to UserDefaults
        UserDefaults.standard.set(name, forKey: "userFullName")
        UserDefaults.standard.synchronize()
        print("Saved name to UserDefaults: \(name)")

    }
    
    func showAppleSignInButton() {
        if let view = self.view {
            if isAuthenticated == false {
                let authorizationButton = ASAuthorizationAppleIDButton()
                authorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
                
                // Add the button to your view
                authorizationButton.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
                authorizationButton.center = view.center
                authorizationButton.tag = 100 // Add a tag for easy removal later
                view.addSubview(authorizationButton)
            }
            isAuthenticated = true

        }
    }
    
    func hideAppleSignInButton() {
        if let view = self.view {
            // Find the Apple Sign In button using its tag and remove it
            if let appleSignInButton = view.viewWithTag(100) {
                appleSignInButton.removeFromSuperview()
            }
        }
    }

    @objc func handleAuthorizationAppleIDButtonPress() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    

    
    func getDayLabels() -> [String] {
        let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 2  // Adjust so Monday is index 0
        var labels = [String]()
        for i in 0..<7 {
            let dayIndex = (todayIndex - i + 7) % 7  // Wrap around
            labels.append(daysOfWeek[dayIndex])
        }
        return labels.reversed()  // Reverse to match the histogram order
    }
    

    

    
    func setupMidnightTimer() {
        let midnight = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)!
        let timer = Timer(fire: midnight, interval: 86400, repeats: true) { _ in
            self.performMidnightTasks()
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc func appDidBecomeActive() {
        if UserDefaults.standard.bool(forKey: "hourlyIncrementActive") {
            startHourlyIncrement()
        }
    }


    func startHourlyIncrement() {
        timer?.invalidate()
        
        let lastIncrementTime = UserDefaults.standard.object(forKey: "lastIncrementTime") as? Date ?? Date()
        let hoursSinceLastIncrement = Calendar.current.dateComponents([.hour], from: lastIncrementTime, to: Date()).hour ?? 0
        
        if hoursSinceLastIncrement > 0 {
            let calendar = Calendar.current
            if calendar.isDate(lastIncrementTime, inSameDayAs: Date()) {
                self.FOOD += 400 * hoursSinceLastIncrement
                self.GOODS += 460 * hoursSinceLastIncrement
                
                // Update today's emissions
                dayByDay[6].food = self.FOOD
                dayByDay[6].goods = self.GOODS
                saveArrays()
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.FOOD += 400
            self.GOODS += 460
            
            // Update today's emissions
            self.dayByDay[6].food = self.FOOD
            self.dayByDay[6].goods = self.GOODS
            
            UserDefaults.standard.set(Date(), forKey: "lastIncrementTime")
            self.saveArrays()
            self.sendDailyUpdate()
        }
    }

    // Add this function to update ENERGY when driving ends
    func updateEnergyAfterDriving() {
        let drivingHours = Int(customLocationManager.drivingTimeInHours)
        let nonDrivingHours = 24 - drivingHours
        self.ENERGY = nonDrivingHours * 600
        
        // Update today's energy emissions
        dayByDay[6].energy = self.ENERGY
        
        saveArrays()
        
        // Update backend
        userScore = self.weekByWeek[4] + self.FOOD + self.ENERGY + self.GOODS - self.offsetGrams
        sendDailyUpdate()
    }
    
    func fetchUserHistory(completion: @escaping ([DailyEmissions]?) -> Void) {
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        guard let url = URL(string: "https://your-function-app-url/api/userhistory/\(userName)") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let userData = try? JSONDecoder().decode(UserScoreData.self, from: data) else {
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                self.dayByDay = userData.dailyHistory
                self.saveArrays()
                completion(userData.dailyHistory)
            }
        }.resume()
    }
    
    func setupDailyEnergyUpdate() {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = 21 // 9 PM
        dateComponents.minute = 30 // 30 minutes past the hour

        // Get the next 9:30 PM
        guard let nextUpdateTime = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .nextTime) else {
            print("Could not calculate next update time")
            return
        }

        // Calculate the time interval until the next 9:30 PM
        let timeInterval = nextUpdateTime.timeIntervalSinceNow

        // Create and schedule the timer
        Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.updateEnergyAfterDriving()
            self?.setupDailyEnergyUpdate() // Schedule the next day's update
        }
    }
    
    func sendDailyUpdate() {
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        let userScore = weekByWeek[4] + FOOD + ENERGY + GOODS + offsetGrams
        
        let parameters: [String: Any] = [
            "userId": userName,
            "weeklyScore": userScore,
            "dailyHistory": dayByDay.map { [
                "carEmissions": $0.carEmissions,
                "food": $0.food,
                "energy": $0.energy,
                "goods": $0.goods
            ]},
            "currentDayEmissions": [
                "carEmissions": dailyCarEmissions,
                "food": FOOD,
                "energy": ENERGY,
                "goods": GOODS
            ]
        ]
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/updateweeklyscore?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            print("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing JSON: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending daily update: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Daily update response status code: \(httpResponse.statusCode)")
            }
        }.resume()
    }

    func performMidnightTasks() {
        print("Before midnight update - dayByDay: \(dayByDay.map { $0.total })")
        
        // Save today's emissions to history before resetting
        dayByDay.removeFirst()
        dayByDay.append(currentDayEmissions)
        
        // Reset daily counters
        dailyCarEmissions = 0
        ENERGY = 0
        FOOD = 0
        GOODS = 0
        
        // Check if it's Monday (weekday == 2 in Calendar)
        let calendar = Calendar.current
        if calendar.component(.weekday, from: Date()) == 2 {
            weekByWeek.removeFirst()
            weekByWeek.append(0)
        }
        
        // Save everything
        saveArrays()
        
        print("After midnight update - dayByDay: \(dayByDay.map { $0.total })")
        
        // Update backend
        sendDailyUpdate()
        
        // Reset driving time for the next day
        customLocationManager.setDrivingTimeToZero()
    }
    
    func saveArrays() {
        UserDefaults.standard.set(ENERGY, forKey: "ENERGY")
        UserDefaults.standard.set(FOOD, forKey: "FOOD")
        UserDefaults.standard.set(GOODS, forKey: "GOODS")
        UserDefaults.standard.set(totalKg, forKey: "totalKg")
        UserDefaults.standard.set(dailyCarEmissions, forKey: "dailyCarEmissions")
        UserDefaults.standard.set(carbonOffsetsPurchased, forKey: "carbonOffsetsPurchased")
        UserDefaults.standard.set(offsetGrams, forKey: "offsetGrams")
        
        // Save daily history
        if let encoded = try? JSONEncoder().encode(dayByDay) {
            UserDefaults.standard.set(encoded, forKey: "dayByDay")
        }
        
        UserDefaults.standard.set(weekByWeek, forKey: "weekByWeek")
    }

    func loadArrays() {
        totalKg = UserDefaults.standard.integer(forKey: "totalKg")
        carbonOffsetsPurchased = UserDefaults.standard.integer(forKey: "carbonOffsetsPurchased")
        FOOD = UserDefaults.standard.integer(forKey: "FOOD")
        GOODS = UserDefaults.standard.integer(forKey: "GOODS")
        ENERGY = UserDefaults.standard.integer(forKey: "ENERGY")
        dailyCarEmissions = UserDefaults.standard.integer(forKey: "dailyCarEmissions")
        offsetGrams = UserDefaults.standard.integer(forKey: "offsetGrams")
        
        // Load dayByDay with proper error handling
        if let savedDayByDay = UserDefaults.standard.data(forKey: "dayByDay"),
           let decodedDayByDay = try? JSONDecoder().decode([DailyEmissions].self, from: savedDayByDay) {
            dayByDay = decodedDayByDay
        } else {
            // Initialize with default values if loading fails
            dayByDay = Array(repeating: DailyEmissions(carEmissions: 1, food: 1, energy: 1, goods: 1), count: 7)
        }
        
        // Load weekByWeek with proper initialization
        if let savedWeekByWeek = UserDefaults.standard.array(forKey: "weekByWeek") as? [Int] {
            weekByWeek = savedWeekByWeek
        } else {
            // Initialize with default values if loading fails
            weekByWeek = Array(repeating: 0, count: 5)
        }
        
        // Debug print
        print("Loaded dayByDay: \(dayByDay.map { $0.total })")
        print("Loaded weekByWeek: \(weekByWeek)")
    }
    
    func endDrivingSession() {
        customLocationManager.isDriving = true
        if customLocationManager.isDriving {
            let emissions = customLocationManager.calculateEmissions(distance: customLocationManager.totalDistance, duration: customLocationManager.totalDuration, carYear: carYear, carMake: carMake, carModel: carModel, carData: carData)
            CalculateduserEmissions = Int(emissions)
            
            // Update dayByDay array (today's emissions)
            dayByDay[6].carEmissions += CalculateduserEmissions
            
            // Update weekByWeek array (this week's emissions)
            weekByWeek[4] += CalculateduserEmissions
            
            // Save the updated arrays
            saveArrays()
            
            print("Total emissions: \(emissions) grams")
            
            // Update emissions on the server
            let username = UserDefaults.standard.string(forKey: "username") ?? "DefaultUser"
            updateEmissions(username: username, emissions: Float(CalculateduserEmissions)) { success in
                if success {
                    print("Emissions updated on server successfully")
                } else {
                    print("Failed to update emissions on server")
                }
            }
            
            customLocationManager.isDriving = false
            customLocationManager.totalDistance = 0
            customLocationManager.totalDuration = 0
        }
    }
    

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            
            if startScreen == true && getStarted.contains(location) {
                getStartedTapped()

            }
        }
    }
    
    func startSimulatedTrip() {
        customLocationManager.startTrackingDriving()
        customLocationManager.isDriving = true
    }
    
// BACKEND CDOMMUNICATION -------------------------

    // Add this method to handle location updates


    
    func sendScore(name: String, score: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/updateweeklyscore?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "userId": name,
            "weeklyScore": score,
            "dailyHistory": dayByDay.map { [
                "carEmissions": $0.carEmissions,
                "food": $0.food,
                "energy": $0.energy,
                "goods": $0.goods
            ]},
            "currentDayEmissions": [
                "carEmissions": dailyCarEmissions,
                "food": FOOD,
                "energy": ENERGY,
                "goods": GOODS
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error serializing JSON: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending score: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response status code: \(httpResponse.statusCode)")
                completion(httpResponse.statusCode == 200)
            } else {
                print("Invalid response")
                completion(false)
            }
        }.resume()
    }
    
    private func fetchAndDisplayLeaderboard() {
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/leaderboard?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching leaderboard data: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let leaderboardData = try JSONDecoder().decode([LeaderboardEntry].self, from: data)
                    // Change sorting order to ascending (lowest first)
                    let sortedLeaderboard = leaderboardData.sorted { $0.weeklyScore < $1.weeklyScore }
                    
                    // Update the leaderboard view with the actual data
                    let leaderboardView = LeaderboardView(leaderboardData: sortedLeaderboard)
                    self.hostingController?.rootView = leaderboardView
                    
                } catch {
                    print("Error decoding leaderboard data: \(error)")
                }
            }
        }.resume()
    }
    

    


// NOTIS -------------------------------------------------
    func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()  // Remove previous notifications if any
        
        // Create content for the notification
        let content = UNMutableNotificationContent()
        content.title = "Daily Carbon Emission Report"
        content.body = generateDailyReport()
        content.sound = .default
        
        // Create a trigger to fire the notification daily at a specific time
        var dateComponents = DateComponents()
        dateComponents.hour = 22  // 10 PM
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        // Schedule the request with the system
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func generateDailyReport() -> String {

        let yesterday = dayByDay[5].carEmissions+dayByDay[5].energy+dayByDay[5].food+dayByDay[5].goods
        let today = dayByDay[6].carEmissions+dayByDay[6].energy+dayByDay[6].food+dayByDay[6].goods
        
        if yesterday>today {
            return "Today, your carbon footprint was \(today) grams, which is \(yesterday-today) grams less than yesterday."
        }
        return "Today, your carbon footprint was \(today) grams, which is \(today-yesterday) grams more than yesterday."
    }
    
    func updateDrivingStatusLabel() {
        // Safely update the label text based on driving status
        drivingStatusLabel?.isHidden = false
        if let drivingStatusLabel = drivingStatusLabel {
            drivingStatusLabel.text = customLocationManager.isDriving ? "Driving: Yes" : "Driving: No"
//            print(customLocationManager.isDriving)
            drivingStatusLabel.fontColor = customLocationManager.isDriving ? .green : .red
        }
    }
    
    @objc func handleDrivingStatusChanged() {
        if !locationTracker.isDriving {
            // Get the emissions from the last driving interval
            let emissions = locationTracker.calculateAndPrintEmissions()
            
            // Update dayByDay, weekByWeek, and allTimeEmissions
            handleDrivingStopped()
        }
    }

    func updateLocalEmissions(emissions: Double) {
        // Update the last day and week values
        //dayByDay[dayByDay.count - 1] += Int(emissions)
        //weekByWeek[weekByWeek.count - 1] += Int(emissions)
        //allTimeEmissions += Int(emissions)
        
        // Update the histograms, pie chart, and leaderboard
    }


    
    func presentLocationPermissionAlert() {
        let alert = UIAlertController(title: "Location Permission", message: "This app needs access to your location to provide a personalized experience.", preferredStyle: .alert)
        
        let allowAction = UIAlertAction(title: "Allow", style: .default) { _ in
            self.requestLocationPermission()  // Request location permission when user taps "Allow"
        }
        
        let denyAction = UIAlertAction(title: "Deny", style: .cancel) { _ in
            // Handle the denial if needed
            self.showCarInputFields()  // Show input fields even if location permission is denied
        }
        
        alert.addAction(allowAction)
        alert.addAction(denyAction)
        
        if let view = self.view, let viewController = view.window?.rootViewController {
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    
    
    func requestLocationPermission() {
        customLocationManager.requestLocationPermission()
        showCarInputFields()  // Show input fields after requesting location permission
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // This method will be called with real-time location updates
        guard let location = locations.last else { return }
    }
    
    func showCarInputFields() {
        hideAppleSignInButton()
        enterCarLabel.isHidden = false
        // Create and configure UIPickerViews
        yearPickerView = createPickerView()
        makePickerView = createPickerView()
        modelPickerView = createPickerView()
        
        // Create and configure UIStackView for horizontal layout
        let hStackView = UIStackView(arrangedSubviews: [yearPickerView, makePickerView, modelPickerView])
        hStackView.axis = .horizontal
        hStackView.alignment = .center
        hStackView.distribution = .fillEqually
        hStackView.spacing = 0
        
        // Set the frame and position of the hStackView
        hStackView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        view?.addSubview(hStackView)
        
        // Add constraints to center the hStackView
        hStackView.centerXAnchor.constraint(equalTo: view!.centerXAnchor).isActive = true
        hStackView.centerYAnchor.constraint(equalTo: view!.centerYAnchor).isActive = true
        hStackView.widthAnchor.constraint(equalTo: view!.widthAnchor, multiplier: 1).isActive = true
        hStackView.heightAnchor.constraint(equalToConstant: 150).isActive = true
        
        // Create and configure UIButton
        confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)
        view?.addSubview(confirmButton)
        
        if let firstYear = years.first {
            carYear = firstYear
            makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
            if let firstMake = makes.first {
                carMake = firstMake
                models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
                carModel = models.first ?? ""
            }
        }

        yearPickerView.selectRow(0, inComponent: 0, animated: false)
        makePickerView.selectRow(0, inComponent: 0, animated: false)
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
        
        // Add constraints to position the confirmButton below the hStackView
        confirmButton.centerXAnchor.constraint(equalTo: view!.centerXAnchor).isActive = true
        confirmButton.topAnchor.constraint(equalTo: hStackView.bottomAnchor, constant: 20).isActive = true
        confirmButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        confirmButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // Set the data source and delegate of the pickers
        yearPickerView.dataSource = self
        yearPickerView.delegate = self
        makePickerView.dataSource = self
        makePickerView.delegate = self
        modelPickerView.dataSource = self
        modelPickerView.delegate = self
    }
    
    func createPickerView() -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.translatesAutoresizingMaskIntoConstraints = false  // Use Auto Layout
        return pickerView
    }
    
    @objc func confirmButtonTapped() {
        print("Confirmed car: \(carYear) \(carMake) \(carModel)")
        endDrivingSession()
        // Save the selected car information
        enterCarLabel.isHidden = true
        UserDefaults.standard.set(carYear, forKey: "carYear")
        UserDefaults.standard.set(carMake, forKey: "carMake")
        UserDefaults.standard.set(carModel, forKey: "carModel")
        locationTracker.setCarDetails(year: carYear, make: carMake, model: carModel, list: carData)
        startSimulatedTrip()
        
        // Update car info on the server
        let username = UserDefaults.standard.string(forKey: "username") ?? "DefaultUser"
        updateCarInfo(username: username) { success in
            DispatchQueue.main.async {
                if success {
                    print("Car info updated on server successfully")
                } else {
                    print("Failed to update car info on server")
                }
                
                // Hide the pickers and confirm button
                self.yearPickerView.isHidden = true
                self.makePickerView.isHidden = true
                self.modelPickerView.isHidden = true
                self.confirmButton.isHidden = true
                self.fullNameTextField!.isHidden = false
                self.fullNameTextField!.becomeFirstResponder()
                self.doneButton!.isHidden = false
                
                // Show the home page
                
            }
        }
    }
    
    @objc func donateCarbonCredits() {
        let purchaseView = CarbonOffsetPurchaseView(
            isPresented: .constant(true),
            allTimeEmissions: $allTimeEmissions, // Use a binding to the class property
            onPurchase: { quantity, kgPerUnit in
                self.purchaseCarbonOffsets(quantity: quantity, kgPerUnit: kgPerUnit)
            },
            onCancel: {
                self.dismissCarbonOffsetPurchaseScreen()
                self.profileButtonTapped()
            },
            updateProfile: self.updateProfile
        )
        
        carbonOffsetPurchaseHostingController = UIHostingController(rootView: purchaseView)
        
        if let hostingController = carbonOffsetPurchaseHostingController, let view = self.view {
            hostingController.view.backgroundColor = .clear
            hostingController.view.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: view.bounds.height - 200)
            view.addSubview(hostingController.view)
            
            // Animate the presentation
            hostingController.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                hostingController.view.alpha = 1
            }
            
            // Hide the donate button
            if let donateButton = view.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Buy Carbon Offsets" }) as? UIButton {
                donateButton.isHidden = true
            }
        }
    }
    
    func purchaseCarbonOffsets(quantity: Int, kgPerUnit: Int) {
        let purchasedKg = quantity * kgPerUnit
        totalKg += purchasedKg
        let amount = kgPerUnit == 400 ? 7.99 : 0.99
        hideAppleSignInButton()
        let totalAmount = amount * Double(quantity)
        self.carbonOffsetsPurchased += quantity

        // Convert kg to grams (negative value for offset)
        let offsetInGrams = -(purchasedKg * 1000)
        userScore = self.weekByWeek[4] + self.FOOD + self.ENERGY + self.GOODS + offsetInGrams
        // Send the offset to the leaderboard
        self.offsetGrams += -offsetInGrams  // Make positive for storage
        UserDefaults.standard.set(self.offsetGrams, forKey: "offsetGrams")
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        sendScore(name: userName, score: userScore) { success in
            if success {
                print("Carbon offset updated in leaderboard successfully")
            } else {
                print("Failed to update carbon offset in leaderboard")
            }
        }
        
        // These updates will affect the pie chart and histogram only
        self.allTimeEmissions -= purchasedKg // Keep this for profile display
        
        // Update UI
        self.updateProfile()
        self.dismissCarbonOffsetPurchaseScreen()
        self.profileButtonTapped()
        
        // Save the updated values
        saveArrays()
    }

    
    func dismissCarbonOffsetPurchaseScreen() {
        if let hostingController = carbonOffsetPurchaseHostingController {
            UIView.animate(withDuration: 0.3, animations: {
                hostingController.view.alpha = 0
            }) { _ in
                hostingController.view.removeFromSuperview()
                self.carbonOffsetPurchaseHostingController = nil
                
                // Show the donate button again
                if let donateButton = self.view?.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.titleLabel?.text == "Buy Carbon Offsets" }) as? UIButton {
                    donateButton.isHidden = false
                }
            }
        }
    }
    
    @objc func showFullLeaderboard() {
        // Existing leaderboard display code

        displayLeaderboard()
    }
    
    

    @objc func showFullHistogram() {
        displayHistogram()
    }

    @objc func showFullPieChart() {
        showPieChart()
    }

    @objc func profileButtonTapped() {
        if self.profileHostingController != nil { return }
        
        // Hide all previews and other views
        homeButtonTapped()
        stackView.isHidden = true
        previewWindows.forEach { $0.isHidden = true }
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        
        // Show profile immediately with loading state
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        let carDetails = "\(carYear) \(carMake) \(carModel)"
        
        // Create initial profile view with loading state
        let profileView = ProfileView(
            username: userName,
            allTimeEmissions: self.allTimeEmissions,
            dailyEmissionsAverage: 0, // Will update
            carDetails: carDetails,
            leaderboardPosition: 0, // Will update
            carbonCreditsPurchased: self.carbonOffsetsPurchased,
            totalKg: self.totalKg
        )
        
        // Show the view immediately
        self.profileHostingController = UIHostingController(rootView: profileView)
        
        if let view = self.view {
            setupProfileUI(in: view)
            
            // Update data asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let daysTracked = max(1, self.weekByWeek.filter { $0 > 0 }.count * 7)
                let dailyAverage = Double(self.allTimeEmissions) / Double(daysTracked)
                
                self.getLeaderboardPosition { position in
                    DispatchQueue.main.async {
                        // Update the profile view with actual data
                        let updatedProfileView = ProfileView(
                            username: userName,
                            allTimeEmissions: self.allTimeEmissions,
                            dailyEmissionsAverage: dailyAverage,
                            carDetails: carDetails,
                            leaderboardPosition: position,
                            carbonCreditsPurchased: self.carbonOffsetsPurchased,
                            totalKg: self.totalKg
                        )
                        self.profileHostingController?.rootView = updatedProfileView
                    }
                }
            }
        }
    }

    private func setupProfileUI(in view: UIView) {
        guard let hostingController = self.profileHostingController else { return }
        
        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = CGRect(
            x: 20,
            y: 100,
            width: view.bounds.width - 40,
            height: view.bounds.height - 250
        )
        
        view.addSubview(hostingController.view)
        
        // Create "Buy Carbon Offsets" button
        let donateButton = UIButton(type: .system)
        donateButton.setTitle("Buy Carbon Offsets", for: .normal)
        donateButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18)
        donateButton.setTitleColor(.white, for: .normal)
        donateButton.backgroundColor = .green
        donateButton.layer.cornerRadius = 10
        donateButton.addTarget(self, action: #selector(self.donateCarbonCredits), for: .touchUpInside)
        
        donateButton.frame = CGRect(
            x: 20,
            y: hostingController.view.frame.maxY - 40,
            width: view.bounds.width - 40,
            height: 50
        )
        
        // Animate the presentation
        hostingController.view.alpha = 0
        donateButton.alpha = 0
        UIView.animate(withDuration: 0.3) {
            hostingController.view.alpha = 1
            donateButton.alpha = 1
            view.backgroundColor = .black
        }
        view.addSubview(donateButton)
        
        // Update the carLabel
        self.carLabel.text = "My Profile"
    }





    @objc func dismissProfile() {
        if let hostingController = self.profileHostingController {
            UIView.animate(withDuration: 0.3, animations: {
                hostingController.view.alpha = 0
                self.view?.backgroundColor = .white
            }) { _ in
                hostingController.view.removeFromSuperview()
                self.profileHostingController = nil
                self.setupHomePage()
            }
        }
    }
    
    func getLeaderboardPosition(completion: @escaping (Int) -> Void) {
        // Return cached value if less than 1 minute old
        if let position = cachedLeaderboardPosition,
           let lastFetch = lastLeaderboardFetch,
           Date().timeIntervalSince(lastFetch) < 60 {
            completion(position)
            return
        }
        
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/leaderboard?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            completion(0)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let data = data,
               let leaderboardData = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) {
                // Change sorting order to ascending (lowest first)
                let sortedLeaderboard = leaderboardData.sorted { $0.weeklyScore < $1.weeklyScore }
                let position = sortedLeaderboard.firstIndex(where: {
                    $0.userId == UserDefaults.standard.string(forKey: "userFullName")
                }).map { $0 + 1 } ?? 0
                
                self.cachedLeaderboardPosition = position
                self.lastLeaderboardFetch = Date()
                completion(position)
            } else {
                completion(0)
            }
        }.resume()
    }
    
    
    
    func setupHomePage() {
        hideAppleSignInButton()
        welcome.isHidden = true
        getStarted.isHidden = true
        // Clear existing views
        self.view?.subviews.forEach { $0.removeFromSuperview() }
        dismissProfile()
        // Set the main view background to white
        self.view?.backgroundColor = .white
        
        // Create a vertical stack view for the preview windows
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create preview windows
        let pieChartWindow = createPreviewWindow(title: "Breakdown", imageName: "piechart", action: #selector(pieChartTapped))
        let histogramWindow = createPreviewWindow(title: "Progress", imageName: "histogram", action: #selector(histogramTapped))
        let leaderboardWindow = createPreviewWindow(title: "Leaderboard", imageName: "leaderboard", action: #selector(leaderboardTapped))
        previewWindows = [pieChartWindow, histogramWindow, leaderboardWindow]
        stackView.addArrangedSubview(pieChartWindow)
        stackView.addArrangedSubview(histogramWindow)
        stackView.addArrangedSubview(leaderboardWindow)
        self.view?.addSubview(stackView)
        
        // Create home button (black, bottom left)
        homeButton = UIButton(type: .system)
        homeButton.setImage(UIImage(systemName: "house.fill"), for: .normal)
        homeButton.tintColor = .black  // Set the color to black
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        self.view?.addSubview(homeButton)
        
        // Create profile button (bottom right)
        let profileButton = createIconButton(imageName: "person.fill", action: #selector(profileButtonTapped))
        self.view?.addSubview(profileButton)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: self.view!.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: self.view!.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: homeButton.topAnchor, constant: -20),
            
            homeButton.leadingAnchor.constraint(equalTo: self.view!.leadingAnchor, constant: 20),
            homeButton.bottomAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            homeButton.widthAnchor.constraint(equalToConstant: 44),
            homeButton.heightAnchor.constraint(equalToConstant: 44),
            
            profileButton.trailingAnchor.constraint(equalTo: self.view!.trailingAnchor, constant: -20),
            profileButton.bottomAnchor.constraint(equalTo: self.view!.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            profileButton.widthAnchor.constraint(equalToConstant: 44),
            profileButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // Helper function to create preview windows
    func createPreviewWindow(title: String, imageName: String, action: Selector) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 10
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.lightGray.cgColor
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold) // Increased font size from 12 to 16
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let contentView: UIView
        let sampledaily = [3, 7, 2, 5, 8, 4, 6]
        let sampleweekly = [20, 25, 18, 30, 22]
        
        if title == "Progress" {
            let histogramPreview = HistogramPreview(dayByDay: sampledaily, weekByWeek: sampleweekly)
            contentView = UIHostingController(rootView: histogramPreview).view
        } else {
            contentView = UIImageView(image: UIImage(named: imageName))
            (contentView as? UIImageView)?.contentMode = .scaleAspectFit
        }
        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: action)
        container.addGestureRecognizer(tapGesture)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10), // Increased top padding
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10), // Increased spacing
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5)
        ])
        
        return container
    }
    
    @objc func drivingStatusChanged() {
        DispatchQueue.main.async {
            self.updateDrivingStatusLabel()
        }
    }
    
    @objc func pieChartTapped() {
        hidePreviews {
            self.showFullPieChart()
        }
    }

    @objc func histogramTapped() {
        hidePreviews {
            self.showFullHistogram()
        }
    }

    @objc func leaderboardTapped() {
        hidePreviews {
            self.showFullLeaderboard()
        }
    }
    
    func hidePreviews(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            self.stackView.alpha = 0
            self.previewWindows.forEach { $0.alpha = 0 }
        }) { _ in
            self.stackView.isHidden = true
            self.previewWindows.forEach { $0.isHidden = true }
            completion()
        }
    }

    // Helper function to create icon buttons
    func createIconButton(imageName: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: imageName), for: .normal)
        button.tintColor = .label
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    func fetchOtherUserEmissions() -> [(String, Double)] {
        // This should return an array of tuples with username and emissions
        // For now, we'll return dummy data
        return [("User1", 100.0), ("User2", 150.0), ("User3", 200.0)]
    }




    @objc func homeButtonTapped() {
        dismissProfile()
        print("Home Button Tapped")
        
        // Remove views
        if let profileWindow = self.view?.viewWithTag(100) {
            profileWindow.removeFromSuperview()
        }
        
        [self.hostingController, self.pieChartHostingController, self.histogramHostingController].forEach { controller in
            controller?.view.removeFromSuperview()
            controller?.removeFromParent()
        }
        
        // Setup the home page
        setupHomePage()
        
        // Show the preview windows again
        stackView.isHidden = false
        previewWindows.forEach { $0.isHidden = false }
        UIView.animate(withDuration: 0.3) {
            self.stackView.alpha = 1
            self.previewWindows.forEach { $0.alpha = 1 }
            self.view?.backgroundColor = .white
        }
        
        // Reset the carLabel text
        carLabel.text = "EcoTrack"
        
        // Hide other buttons that might be visible
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        progress.isHidden = true
        // Bring progress label to front
    }


    
    
    func showNewButtons() {
        // Create and configure the 'View Leaderboard' button
        carLabel.text = "Main Menu"
        viewLeaderboardButton.setTitle("View Leaderboard", for: .normal)
        viewLeaderboardButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)  // Set font
        viewLeaderboardButton.setTitleColor(.white, for: .normal)
        viewLeaderboardButton.addTarget(self, action: #selector(viewLeaderboardButtonTapped), for: .touchUpInside)
        viewLeaderboardButton.isHidden = false
        
        // Create and configure the 'My Progress' button
        
        myProgressButton.setTitle("My Progress", for: .normal)
        myProgressButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)  // Set font
        myProgressButton.setTitleColor(.white, for: .normal)
        myProgressButton.addTarget(self, action: #selector(myProgressButtonTapped), for: .touchUpInside)
        myProgressButton.isHidden = false
        
        
        // Create and configure the 'My Badges' button
        
        
        myBadgesButton.setTitle("Today's Emissions", for: .normal)
        myBadgesButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 20)
        myBadgesButton.setTitleColor(.white, for: .normal)
        myBadgesButton.addTarget(self, action: #selector(todaysEmissionsButtonTapped), for: .touchUpInside)
        myBadgesButton.isHidden = false
        
        // Add buttons to the view
        if let view = self.view {
            // Create a vertical stack view to hold the buttons
            let vStackView = UIStackView(arrangedSubviews: [viewLeaderboardButton, myProgressButton, myBadgesButton])
            vStackView.axis = .vertical
            vStackView.alignment = .center
            vStackView.distribution = .equalSpacing
            vStackView.spacing = 20
            vStackView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(vStackView)
            NSLayoutConstraint.activate([
                vStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                vStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                viewLeaderboardButton.widthAnchor.constraint(equalToConstant: 200),
                myProgressButton.widthAnchor.constraint(equalToConstant: 200),
                myBadgesButton.widthAnchor.constraint(equalToConstant: 200)
            ])
        }
    }
    
    @objc func todaysEmissionsButtonTapped() {
        showPieChart()
    }

    @objc func viewLeaderboardButtonTapped() {
        //let userEmissions = 0  // User's emissions are initially set to 0
        let randomEmissions1 = Int.random(in: 0...500)
        let randomEmissions2 = Int.random(in: 0...500)
        let randomEmissions3 = Int.random(in: 0...500)
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        // Store other users' emissions for display
        let otherUserEmissions = [randomEmissions1, randomEmissions2, randomEmissions3]
        displayLeaderboard()
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)

    }

    @objc func myProgressButtonTapped() {
        carLabel.text = "My Progress"
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true
        
        // Create and display the histogram
        displayHistogram()
        
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
    }
    
    func handleDrivingStopped() {
        let emissions = customLocationManager.calculateAndSendEmissions()
        dailyCarEmissions += Int(emissions)
        
        // Update today's emissions in dayByDay array
        dayByDay[6].carEmissions = dailyCarEmissions
        
        // Update weekly total
        weekByWeek[4] += Int(emissions)
        
        // Debug print
        print("Updated emissions - dailyCarEmissions: \(dailyCarEmissions)")
        print("Updated dayByDay: \(dayByDay.map { $0.total })")
        print("Updated weekByWeek: \(weekByWeek)")
        
        // Save the updates
        saveArrays()
        
        // Update backend
        sendDailyUpdate()
        
        allTimeEmissions += Int(emissions)
        updateProfile()
    }


    func updateWeeklyHistogram() {
        //let weeklyEmissions = calculateWeeklyEmissions()  // Calculate the sum of the week // Store the weekly emissions in the last index
        print("weekByWeek updated: \(weekByWeek)")
    }
    
    func calculateWeeklyEmissions() -> Int {
        let dayLabels = getDayLabels()  // Get the correct labels
        var sum = 0

        // Start from today's emissions (right-most bar) and move left
        for (index, day) in dayLabels.enumerated().reversed() {
            sum += dayByDay[index].carEmissions+dayByDay[index].energy+dayByDay[index].food+dayByDay[index].goods  // Add the emissions for this day
            if day == "Mon" {  // Stop once we hit the bar labeled "Mon"
                break
            }
        }
        print("Weekly emissions calculated: \(sum)")
        return sum
    }


    
    func displayHistogram() {
        print("DayByDay data: \(dayByDay.map { $0.total })")
        print("WeekByWeek data: \(weekByWeek)")
        loadArrays()
        print("DayByDay data: \(dayByDay.map { $0.total })")
        print("WeekByWeek data: \(weekByWeek)")
        
        if customLocationManager.isDriving {
            handleDrivingStopped()
        }
        
        // Create and show histogram
        weekByWeek[4] = calculateWeeklyEmissions()
        let histogramView = HistogramView(dayByDay: dayByDay, weekByWeek: weekByWeek)
        histogramHostingController = UIHostingController(rootView: histogramView)

        if let view = self.view {
            // Remove any existing histogram view
            histogramHostingController?.view.removeFromSuperview()
            
            // Set the frame to cover a portion of the screen
            let width: CGFloat = view.bounds.width * 0.9
            let height: CGFloat = view.bounds.height * 0.6
            let x = (view.bounds.width - width) / 2
            let y = (view.bounds.height - height) / 2
            
            histogramHostingController?.view.frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Add corner radius for a nicer look
            histogramHostingController?.view.layer.cornerRadius = 10
            histogramHostingController?.view.clipsToBounds = true
            
            view.addSubview(histogramHostingController!.view)
            
            // Optionally animate the presentation
            histogramHostingController?.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.histogramHostingController?.view.alpha = 1
            }
        }

    }
    
    func displayLeaderboard() {
        offsetGrams = UserDefaults.standard.integer(forKey: "offsetGrams")
        userScore = self.weekByWeek[4] - self.offsetGrams
        print(offsetGrams)
        print(userScore)
        let userName = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
        self.sendScore(name: UserDefaults.standard.string(forKey: "userFullName") ?? "Not found", score: userScore) { success in
            if success {
                print("Succcess")
            } else {
                print("Failed to send score")
            }
        }
        // Show loading view first
        let loadingView = LoadingDotsView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        loadingView.center = view?.center ?? CGPoint(x: 0, y: 0)
        loadingView.backgroundColor = .clear
        view?.addSubview(loadingView)
        
        // Fetch data
        guard let url = URL(string: "https://functionappbackend.azurewebsites.net/api/leaderboard?code=lblCgRPcIKqtmdyf8Py_cL93EEYeSNlsr_5OeYTrfNgeAzFuourfNQ%3D%3D") else {
            print("Invalid URL")
            loadingView.removeFromSuperview()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Remove loading view
                loadingView.stopAnimation()
                loadingView.removeFromSuperview()
                
                if let error = error {
                    print("Error fetching leaderboard data: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    let leaderboardData = try JSONDecoder().decode([LeaderboardEntry].self, from: data)
                    // Filter out "Not found" entries before sorting
                    let filteredLeaderboard = leaderboardData.filter { $0.userId != "Not found" }
                    // Change sorting order to ascending (lowest first)
                    let sortedLeaderboard = filteredLeaderboard.sorted { $0.weeklyScore < $1.weeklyScore }
                    
                    let leaderboardView = LeaderboardView(leaderboardData: sortedLeaderboard)
                    self.hostingController = UIHostingController(rootView: leaderboardView)
                    
                    if let view = self.view {
                        // Set up the leaderboard UI
                        let width: CGFloat = view.bounds.width * 0.9
                        let height: CGFloat = view.bounds.height * 0.7
                        let x = (view.bounds.width - width) / 2
                        let y = (view.bounds.height - height) / 2
                        
                        self.hostingController?.view.frame = CGRect(x: x, y: y, width: width, height: height)
                        self.hostingController?.view.layer.cornerRadius = 10
                        self.hostingController?.view.clipsToBounds = true
                        view.addSubview(self.hostingController!.view)
                    }
                } catch {
                    print("Error decoding leaderboard data: \(error)")
                }
            }
        }.resume()
    }

    func sendScoreAndFetchLeaderboard(userName: String) {
        userScore = self.weekByWeek[4] + self.FOOD + self.ENERGY + self.GOODS - self.offsetGrams
        self.sendScore(name: UserDefaults.standard.string(forKey: "userFullName") ?? "Not found", score: userScore) { success in
            if success {
                self.fetchAndDisplayLeaderboard()
            } else {
                print("Failed to send score")
            }
        }
    }
    


    // Define a struct to match the backend's data structure
    struct LeaderboardEntry: Codable {
        let userId: String  // Change from 'name' to 'userId'
        let weeklyScore: Double  // Change from 'score' to 'weeklyScore'
        
        // Add coding keys to map the JSON fields to our struct properties
        enum CodingKeys: String, CodingKey {
            case userId
            case weeklyScore
        }
    }

    struct LeaderboardView: View {
        let leaderboardData: [LeaderboardEntry]
        
        var body: some View {
            VStack {
                Text("Leaderboard")
                    .font(.title)
                    .padding()
                List(leaderboardData.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .font(.headline)
                            .frame(width: 30, alignment: .leading)
                        
                        Text(leaderboardData[index].userId)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(Int(leaderboardData[index].weeklyScore))")
                            .font(.body)
                    }
                    .listRowBackground(
                        isCurrentUser(leaderboardData[index].userId) ?
                            Color.green.opacity(0.2) :
                            Color.clear
                    )
                }
            }
        }
        
        private func isCurrentUser(_ userId: String) -> Bool {
            let currentUser = UserDefaults.standard.string(forKey: "userFullName") ?? "Not found"
            return userId == currentUser
        }
    }

    struct HistogramView: View {
        let dayByDay: [DailyEmissions]
        let weekByWeek: [Int]
        @State private var currentPage = 0
        
        var body: some View {
            VStack {
                TabView(selection: $currentPage) {
                    DailyHistogram(emissions: dayByDay)
                        .tag(0)
                    
                    WeeklyHistogram(data: weekByWeek)
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<2) { index in
                        Circle()
                            .fill(currentPage == index ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    struct DailyHistogram: View {
        let emissions: [DailyEmissions]
        
        var maxEmission: Int {
            emissions.map { $0.total }.max() ?? 1
        }
        
        var body: some View {
            VStack {
                Text("Past 7 Days")
                    .font(.title)
                    .padding()
                
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(0..<7) { index in
                        VStack {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 40, height: 200)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 40, height: CGFloat(emissions[index].total) / CGFloat(maxEmission) * 200)
                            }
                            Text(DailyHistogram.getDayLabel(for: index))
                                .font(.caption)
                            Text("\(emissions[index].total)")
                                .font(.system(size: 8))
                        }
                    }
                }
                .padding()
                
                Text("Daily Emissions in grams CO2")
                    .font(.caption)
                    .padding()
            }
        }
        
        static func getDayLabel(for index: Int) -> String {
            let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
            return daysOfWeek[(todayIndex - (6 - index) + 7) % 7]
        }
    }

    struct WeeklyHistogram: View {
        let data: [Int]
        let maxEmission: Int
        
        init(data: [Int]) {
            self.data = data
            self.maxEmission = data.max() ?? 1 // Avoid division by zero
        }
        
        var body: some View {
            VStack {
                // Reduced font size for title
                Text("Past 5 Weeks")
                    .font(.system(size: 30))  // Smaller font size
                    .padding()
                
                HStack(alignment: .bottom, spacing: 20) {
                    ForEach(0..<5) { index in
                        VStack {
                            ZStack(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 50, height: 200)
                                
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 50, height: CGFloat(self.data[index]) / CGFloat(self.maxEmission) * 200)
                            }
                            
                            // Reduced font size for week label
                            Text("Week \(5 - index)")
                                .font(.system(size: 10))  // Smaller caption size
                            
                            // Reduced font size for emission label
                            Text("\(self.data[index])")
                                .font(.system(size: 8))  // Smaller caption size
                        }
                    }
                }
                .padding()
                
                // Reduced font size for footer text
                Text("Weekly Emissions in grams CO2")
                    .font(.system(size: 12))  // Smaller caption size
                    .padding()
            }
        }
    }


    func createProgressLabel() -> UILabel {
        let label = UILabel(frame: CGRect(x: 30, y: 100, width: 200, height: 30))
        label.text = "Progress"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.isHidden = true // Initially hidden
        return label
    }
    

    
    // Implement UITextFieldDelegate methods
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Handle the event when text field editing begins
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Handle the event when text field editing ends
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Handle the event when return key is pressed
        textField.resignFirstResponder()
        return true
    }
}

// Conform to UIPickerViewDataSource and UIPickerViewDelegate
extension GameScene: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case yearPickerView:
            return years.count
        case makePickerView:
            return makes.count
        case modelPickerView:
            return models.count
        default:
            return 0
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case yearPickerView:
            return years[row]
        case makePickerView:
            return makes[row]
        case modelPickerView:
            return models[row]
        default:
            return nil
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case yearPickerView:
            carYear = years[row]
            makes = Array(Set(carData.filter { $0[0] == carYear }.map { $0[1] })).sorted()
            print("Selected Year: \(carYear), Available Makes: \(makes)")
            makePickerView.reloadAllComponents()
            makePickerView.selectRow(0, inComponent: 0, animated: false)
            carMake = makes.first ?? ""
            updateModels()
        case makePickerView:
            if row < makes.count {
                carMake = makes[row]
                print("Selected Make: \(carMake)")
                updateModels()
            } else {
                print("Error: Selected row \(row) is out of bounds for makes array with count \(makes.count)")
            }
        case modelPickerView:
            if row < models.count {
                carModel = models[row]
                print("Selected Model: \(carModel)")
            } else {
                print("Error: Selected row \(row) is out of bounds for models array with count \(models.count)")
            }
        default:
            break
        }
    }

    func updateModels() {
        models = Array(Set(carData.filter { $0[0] == carYear && $0[1] == carMake }.map { $0[2] })).sorted()
        print("Available Models: \(models)")
        modelPickerView.reloadAllComponents()
        modelPickerView.selectRow(0, inComponent: 0, animated: false)
        carModel = models.first ?? ""
    }
}
extension GameScene {
    
    func createUser(username: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters = ["username": username]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
    
    func showPickerViews() {
        // Remove any existing picker views
        yearPickerView?.removeFromSuperview()
        makePickerView?.removeFromSuperview()
        modelPickerView?.removeFromSuperview()
        
        // Create and setup picker views

        // Show the car label
        carLabel.isHidden = false
        carLabel.fontName = "AvenirNext-Bold"
        carLabel.zPosition = 2
        carLabel.fontColor = SKColor.white
        
        // Request location permission
        presentLocationPermissionAlert()
    }
    
    func updateCarInfo(username: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user/\(username)/car") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "username": username,
            "car_year": carYear,
            "car_make": carMake,
            "car_model": carModel
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
    
    func updateEmissions(username: String, emissions: Float, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:5000/api/user/\(username)/emissions") else {
            print("Invalid URL")
            completion(false)
            return
        }
        
        let parameters: [String: Any] = [
            "username": username,
            "emissions": emissions
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response")
                completion(false)
                return
            }
            
            completion(true)
        }
        
        task.resume()
    }
    
    struct DailyEmissions: Codable {
        var carEmissions: Int
        var food: Int
        var energy: Int
        var goods: Int
        
        var total: Int {
            return carEmissions + food + energy + goods
        }
    }

    struct UserScoreData: Codable {
        let userId: String
        let weeklyScore: Int
        let dailyHistory: [DailyEmissions]
        let currentDayEmissions: DailyEmissions
    }
}
extension GameScene {
    func showPieChart() {
        carLabel.text = "Today's Emissions"
        viewLeaderboardButton.isHidden = true
        myProgressButton.isHidden = true
        myBadgesButton.isHidden = true

        // Get today's emissions from dayByDay[6] (current day)
        let todayEmissions = dayByDay[6]
        
        print("Pie Chart Values:")
        print("Car Emissions: \(todayEmissions.carEmissions)")
        print("Food: \(todayEmissions.food)")
        print("Energy: \(todayEmissions.energy)")
        print("Goods: \(todayEmissions.goods)")

        let pieChartView = PieChartView(
            userEmissions: todayEmissions.carEmissions,
            food: todayEmissions.food,
            energy: todayEmissions.energy,
            goods: todayEmissions.goods
        )
        
        pieChartHostingController = UIHostingController(rootView: pieChartView)
        
        if let view = self.view, let hostingController = pieChartHostingController {
            // Remove any existing pie chart view
            view.subviews.first(where: { $0.tag == 100 })?.removeFromSuperview()
            
            // Set the frame to cover a portion of the screen
            let width: CGFloat = view.bounds.width * 0.9
            let height: CGFloat = view.bounds.height * 0.7
            let x = (view.bounds.width - width) / 2
            let y = (view.bounds.height - height) / 2
            
            hostingController.view.frame = CGRect(x: x, y: y, width: width, height: height)
            
            // Add corner radius for a nicer look
            hostingController.view.layer.cornerRadius = 10
            hostingController.view.clipsToBounds = true
            hostingController.view.tag = 100
            
            view.addSubview(hostingController.view)
            
            // Animate the presentation
            hostingController.view.alpha = 0
            UIView.animate(withDuration: 0.3) {
                hostingController.view.alpha = 1
            }
        }
        
        homeButton.addTarget(self, action: #selector(homeButtonTapped), for: .touchUpInside)
    }
}

struct PieChartPreview: View {
    let userEmissions: Int
    let food: Int
    let energy: Int
    let goods: Int
    
    var body: some View {
        PieChartView(userEmissions: userEmissions, food: food, energy: energy, goods: goods)
            .frame(width: 100, height: 100)
            .background(Color.white) // Changed from Color.black to Color.white
    }
}

// Histogram Preview
struct HistogramPreview: View {
    let dayByDay: [Int]
    let weekByWeek: [Int]
    
    var body: some View {
        GeometryReader { outerGeometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<7) { index in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: outerGeometry.size.width * 0.9 / 9,
                               height: CGFloat(dayByDay[index]) / CGFloat(dayByDay.max() ?? 1) * outerGeometry.size.height * 0.63)
                }
            }
            .frame(width: outerGeometry.size.width * 0.9, height: outerGeometry.size.height * 0.9, alignment: .bottom)
            .position(x: outerGeometry.size.width / 2, y: outerGeometry.size.height * 0.4) // Changed from 0.6 to 0.5
        }
    }
}


// Leaderboard Preview
struct LeaderboardPreview: View {
    let userEmissions: (String, Double)
    let otherEmissions: [(String, Double)]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<min(5, otherEmissions.count + 1), id: \.self) { index in
                    if index < otherEmissions.count && otherEmissions[index].1 > userEmissions.1 {
                        EmissionBar(username: otherEmissions[index].0,
                                    emission: otherEmissions[index].1,
                                    maxEmission: otherEmissions[0].1,
                                    width: geometry.size.width,
                                    height: geometry.size.height / 5)
                    } else {
                        EmissionBar(username: userEmissions.0,
                                    emission: userEmissions.1,
                                    maxEmission: otherEmissions[0].1,
                                    width: geometry.size.width,
                                    height: geometry.size.height / 5)
                            .foregroundColor(.green)
                            .background(Color.white) // Changed from Color.black to Color.white
                    }
                }
            }
        }
        .background(Color.white) // Added this line to ensure the entire preview has a white background
    }
}

struct EmissionBar: View {
    let username: String
    let emission: Double
    let maxEmission: Double
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.blue)
                .frame(width: CGFloat(emission / maxEmission) * width * 0.8, height: height)
            Text(username.prefix(3))
                .font(.system(size: 10))
                .frame(width: width * 0.2, alignment: .leading)
                .foregroundColor(.white) // Added this line to ensure text is visible on white background
        }
        .background(Color.white) // Added this line to ensure the entire bar has a white background
    }
}

struct ProfileView: View {
    let username: String
    @State var allTimeEmissions: Int
    let dailyEmissionsAverage: Double
    let carDetails: String
    let leaderboardPosition: Int
    let carbonCreditsPurchased: Int
    let totalKg: Int  // Changed from carbonOffsetsKg to totalKg

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Profile: \(username)")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Car: \(carDetails)")
                Text("KGs of CO2 removed (Carbon Offsets):(\(totalKg) kg)")  // Modified this line
            }
            .font(.body)
        }
        .padding()
        .background(Color.black)
        .foregroundColor(.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}


struct CarbonOffsetPurchaseView: View {
    @Binding var isPresented: Bool
    @Binding var allTimeEmissions: Int
    var onPurchase: (Int, Int) -> Void
    var onCancel: () -> Void
    var updateProfile: () -> Void
    
    @State private var selectedOption: Int? = nil
    @State private var quantity: String = ""
    @State private var showingPaymentSheet = false
    
    private let paymentHandler = PaymentHandler()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Buy Carbon Offsets")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                Button(action: { selectedOption = 400 }) {
                    HStack {
                        Text("400 kg for $7.99")
                        Spacer()
                        if selectedOption == 400 {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .background(selectedOption == 400 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                
                Button(action: { selectedOption = 30 }) {
                    HStack {
                        Text("30 kg for $0.99")
                        Spacer()
                        if selectedOption == 30 {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding()
                    .background(selectedOption == 30 ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                
                HStack {
                    Text("Quantity:")
                    TextField("Enter quantity", text: $quantity)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(selectedOption == nil)
                        .opacity(selectedOption == nil ? 0.5 : 1)
                }
                .padding(.top)
                
                if let selected = selectedOption, let qty = Int(quantity), !quantity.isEmpty {
                    ApplePayButton(type: .buy, style: .black) {
                        let amount = selected == 400 ? 7.99 : 0.99
                        let totalAmount = amount * Double(qty)
                        paymentHandler.startPayment(amount: totalAmount) { success in
                            if success {
                                onPurchase(qty, selected)
                                allTimeEmissions -= qty * selected // Decrease allTimeEmissions
                                updateProfile()
                                isPresented = false
                            }
                        }
                    }
                    .frame(height: 45)
                    .disabled(selectedOption == nil || quantity.isEmpty)
                }
                
                Button(action: {
                    isPresented = false
                    onCancel()
                }) {
                    Text("Cancel")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
}

struct LoadingView: View {
    @State private var isSpinning = false
    @State private var isPulsing = false
    let message: String
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            // Loading container
            VStack {
                ZStack {
                    // Spinning circle
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .rotationEffect(Angle(degrees: isSpinning ? 360 : 0))
                        .animation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false), value: isSpinning)
                    
                    // Logo
                    Image("leaf_logo") // Make sure to add your logo to Assets.xcassets
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.1 : 0.9)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
                }
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.top, 8)
            }
            .padding(40)
            .background(Color.black.opacity(0.7))
            .cornerRadius(20)
        }
        .onAppear {
            isSpinning = true
            isPulsing = true
        }
    }
}

// Helper extension for GameScene
extension GameScene {
    func showLoadingView(withMessage message: String) -> UIViewController {
        let loadingView = LoadingView(message: message)
        let hostingController = UIHostingController(rootView: loadingView)
        hostingController.view.backgroundColor = .clear
        
        if let view = self.view {
            hostingController.view.frame = view.bounds
            view.addSubview(hostingController.view)
        }
        
        return hostingController
    }
    
    func hideLoadingView(_ loadingViewController: UIViewController) {
        DispatchQueue.main.async {
            loadingViewController.view.removeFromSuperview()
        }
    }
}




struct ApplePayButton: UIViewRepresentable {
    var type: PKPaymentButtonType
    var style: PKPaymentButtonStyle
    var action: () -> Void
    
    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        var action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonTapped() {
            action()
        }
    }
}

class PaymentHandler: NSObject {
    
    var paymentCompletion: ((Bool) -> Void)?
    
    func startPayment(amount: Double, completion: @escaping (Bool) -> Void) {
        self.paymentCompletion = completion
        let paymentRequest = PKPaymentRequest()
        paymentRequest.merchantIdentifier = "merchant.com.ecotrack"
        paymentRequest.supportedNetworks = [.visa, .masterCard, .amex]
        paymentRequest.supportedCountries = ["US", "CA"]
        paymentRequest.merchantCapabilities = .capability3DS
        paymentRequest.countryCode = "US"
        paymentRequest.currencyCode = "USD"
        
        let carbonOffset = PKPaymentSummaryItem(label: "Carbon Offset", amount: NSDecimalNumber(value: amount))
        paymentRequest.paymentSummaryItems = [carbonOffset]
        
        let controller = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        if let controller = controller {
            controller.delegate = self
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(controller, animated: true, completion: nil)
            }
        }
    }
}

extension PaymentHandler: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // Process the payment here
        // For this example, we'll just simulate a successful payment
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        self.paymentCompletion?(true)
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let viewController = windowScene.windows.first?.rootViewController {
            viewController.dismiss(animated: true, completion: nil)
        }
        // If the payment wasn't successful (e.g., user cancelled), call the completion handler with false
        if self.paymentCompletion != nil {
            self.paymentCompletion?(false)
            self.paymentCompletion = nil
        }
    }
}
extension Notification.Name {
    static let drivingStatusChanged = Notification.Name("drivingStatusChanged")
}

extension GameScene: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Retrieve the user's email
            if let email = appleIDCredential.email {
                // Save the email to UserDefaults
                UserDefaults.standard.set(email, forKey: "UserEmail")
                print("User Email saved: \(email)")
            } else {
                print("Email is not available.")
            }
            // Check if car details are already saved
            if UserDefaults.standard.string(forKey: "carYear") == nil ||
               UserDefaults.standard.string(forKey: "carMake") == nil ||
               UserDefaults.standard.string(forKey: "carModel") == nil {
                // Car details are not saved, show the car input fields
                DispatchQueue.main.async {
                    self.showCarInputFields()
                }
            } else {
                // Car details are already saved, proceed to the home page
                DispatchQueue.main.async {
                    self.setupHomePage()
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle sign-in error
        print("Apple ID authorization failed: \(error.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension GameScene: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view!.window!
    }
}

class LoadingDotsView: UIView {
    private var dotViews: [UIView] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var loadingLabel: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLabel()
        setupDots()
        startAnimation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLabel()
        setupDots()
        startAnimation()
    }
    
    private func setupLabel() {
        loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 20))
        loadingLabel.text = "Loading"
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: 14)
        addSubview(loadingLabel)
    }
    
    private func setupDots() {
        for i in 0..<3 {
            let dot = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            dot.backgroundColor = .white
            dot.layer.cornerRadius = 5
            dot.center = CGPoint(x: center.x + CGFloat(i - 1) * 20, y: center.y)
            addSubview(dot)
            dotViews.append(dot)
        }
        centerDotsAndLabel()
    }
    
    private func centerDotsAndLabel() {
        // Center label above dots
        loadingLabel.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2 - 35)
        
        // Center dots below label
        let totalWidth = CGFloat(dotViews.count - 1) * 20
        let startX = (bounds.width - totalWidth) / 2
        
        for (index, dot) in dotViews.enumerated() {
            dot.center = CGPoint(x: startX + CGFloat(index) * 20, y: bounds.height / 2 + 10)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        centerDotsAndLabel()
    }
    
    private func startAnimation() {
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateAnimation() {
        let elapsed = CACurrentMediaTime() - startTime
        
        for (index, dot) in dotViews.enumerated() {
            let delay = Double(index) * 0.2
            let y = -10 * sin(2 * .pi * (elapsed - delay))
            dot.transform = CGAffineTransform(translationX: 0, y: y)
        }
    }
    
    func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    deinit {
        stopAnimation()
    }
}
