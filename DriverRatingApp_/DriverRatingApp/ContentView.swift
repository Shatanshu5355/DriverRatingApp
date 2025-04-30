import SwiftUI
import CoreMotion
import CoreLocation

// Model for session report data
struct SessionReport {
    let speed: Double
    let accelerationX: Double
    let accelerationY: Double
    let score: Double
    let timestamp: Date
}

struct ContentView: View {
    // Motion and Location Managers
    let motionManager = CMMotionManager()
    let locationManager = CLLocationManager()
    
    // State properties to store sensor data
    @State private var speed: Double = 0.0
    @State private var accelerationX: Double = 0.0
    @State private var accelerationY: Double = 0.0
    @State private var accelerationZ: Double = 0.0
    @State private var driverScore: Double = 100.0 // Start with a perfect score
    @State private var isTracking: Bool = false
    @State private var sessionReports: [SessionReport] = [] // Store session reports
    @State private var speedLimit: Double = 60.0 // Default speed limit
    @State private var maxAcceleration: Double = 3.0 // Default max acceleration
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                VStack(spacing: 20) {
                    // Header
                    Text("Driver Rating System")
                        .font(.system(size: geometry.size.width * 0.08, weight: .bold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(radius: 5)
                    
                    // Sensor Data Display
                    VStack(spacing: 10) {
                        SensorDataView(
                            title: "Speed",
                            value: String(format: "%.2f km/h", speed),
                            isAlert: speed > speedLimit
                        )
                        SensorDataView(
                            title: "Acceleration X",
                            value: String(format: "%.2f", accelerationX)
                        )
                        SensorDataView(
                            title: "Acceleration Y",
                            value: String(format: "%.2f", accelerationY)
                        )
                        SensorDataView(
                            title: "Acceleration Z",
                            value: String(format: "%.2f", accelerationZ)
                        )
                        SensorDataView(
                            title: "Driver Score",
                            value: String(format: "%.2f", driverScore),
                            isBold: true
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    
                    // Start/Stop Session Buttons
                    HStack {
                        SessionButton(
                            title: "Start Session",
                            backgroundColor: .blue,
                            geometry: geometry
                        ) {
                            if !isTracking {
                                resetSession() // Reset data for a new session
                                startTracking()
                                startLocationTracking()
                                isTracking = true
                            }
                        }
                        .padding(.trailing)
                        
                        SessionButton(
                            title: "Stop Session",
                            backgroundColor: .red,
                            geometry: geometry
                        ) {
                            if isTracking {
                                stopTracking()
                                generateSessionReport() // Generate a report for this session
                                isTracking = false
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Scores Button
                    Button(action: printDriverScores) {
                        Text("Print Scores")
                            .padding()
                            .frame(maxWidth: geometry.size.width * 0.8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .shadow(radius: 5)
                    }
                    .padding(.top)
                    
                    // Settings Button
                    NavigationLink(
                        destination: SettingsView(
                            speedLimit: $speedLimit,
                            maxAcceleration: $maxAcceleration
                        )
                    ) {
                        Text("Settings")
                            .padding()
                            .frame(maxWidth: geometry.size.width * 0.8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.top)
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Driver Metrics")
                .onAppear {
                    // Request location permissions when the view appears
                    locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    // Function to reset data for a new session
    func resetSession() {
        speed = 0.0
        accelerationX = 0.0
        accelerationY = 0.0
        accelerationZ = 0.0
        driverScore = 100.0
    }
    
    // Function to start motion tracking
    func startTracking() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1 // Update every 0.1 seconds
            motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data, error) in
                if let validData = data {
                    DispatchQueue.main.async {
                        accelerationX = validData.acceleration.x
                        accelerationY = validData.acceleration.y
                        accelerationZ = validData.acceleration.z
                        updateDriverScore() // Update score with new acceleration data
                    }
                }
            }
        } else {
            print("Accelerometer not available")
        }
    }
    
    // Function to start location tracking
    func startLocationTracking() {
        locationManager.delegate = LocationDelegate(speedBinding: $speed) { newSpeed in
            DispatchQueue.main.async {
                self.speed = newSpeed
                updateDriverScore() // Update score with new speed
            }
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    // Function to stop tracking
    func stopTracking() {
        motionManager.stopAccelerometerUpdates()
        locationManager.stopUpdatingLocation()
        print("Tracking stopped")
    }
    
    // Update the driver score based on speed and acceleration
    func updateDriverScore() {
        let maxAcceleration = self.maxAcceleration // user-defined max acceleration
        let maxDeceleration = -3.0 // Max deceleration in m/s²
        
        var score = 100.0 // Start with a perfect score
        
        // Speed penalty
        if speed > speedLimit {
            let excessSpeed = speed - speedLimit
            score -= excessSpeed * 2 // Penalty factor for overspeeding
        }
        
        // Acceleration penalty
        let acceleration = sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ) // Calculate total acceleration
        if acceleration > maxAcceleration {
            score -= (acceleration - maxAcceleration) * 5 // Penalty factor for excessive acceleration
        }
        
        // Deceleration penalty (using Y axis for braking)
        if accelerationY < maxDeceleration {
            score -= (-accelerationY - maxDeceleration) * 5 // Penalty for aggressive braking
        }
        
        // Smoothness score based on abrupt changes in acceleration
        let smoothnessThreshold = 5.0 // Example threshold for abrupt changes
        if accelerationX > smoothnessThreshold || accelerationY > smoothnessThreshold || accelerationZ > smoothnessThreshold {
            score -= 10 // Penalty for abrupt changes
        }
        
        // Ensure score remains within the 0 to 100 range
        driverScore = max(0, min(100, score))
        print("Driver Score updated: \(driverScore)")
    }
    
    // Function to generate a session report
    func generateSessionReport() {
        let report = SessionReport(speed: speed, accelerationX: accelerationX, accelerationY: accelerationY, score: driverScore, timestamp: Date())
        sessionReports.append(report)
        print("Session Report Generated: \(report)")
    }
    
    // Function to print all driver scores
    func printDriverScores() {
        print("Driver Scores Report:")
        for (index, report) in sessionReports.enumerated() {
            print("""
                Session \(index + 1):
                - Timestamp: \(report.timestamp)
                - Speed: \(String(format: "%.2f km/h", report.speed))
                - Acceleration X: \(String(format: "%.2f", report.accelerationX))
                - Acceleration Y: \(String(format: "%.2f", report.accelerationY))
                - Driver Score: \(String(format: "%.2f", report.score))
                """)
        }
    }
}

// Sensor Data Display Component
struct SensorDataView: View {
    var title: String
    var value: String
    var isAlert: Bool = false
    var isBold: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(isBold ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text(value)
                .foregroundColor(isAlert ? .red : .primary)
                .fontWeight(isBold ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

// Custom Button View
struct SessionButton: View {
    var title: String
    var backgroundColor: Color
    var geometry: GeometryProxy
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: geometry.size.width * 0.4)
                .padding()
                .background(backgroundColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }
}

// Location Delegate
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    @Binding var speedBinding: Double
    var onUpdate: ((Double) -> Void)?

    init(speedBinding: Binding<Double>, onUpdate: ((Double) -> Void)? = nil) {
        _speedBinding = speedBinding
        self.onUpdate = onUpdate
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("No locations available")
            return
        }
        let speed = location.speed * 3.6 // Convert speed to km/h
        print("New location: \(location.coordinate.latitude), \(location.coordinate.longitude), speed: \(speed) km/h")
        onUpdate?(speed) // Update speed
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}

// Settings View
struct SettingsView: View {
    @Binding var speedLimit: Double
    @Binding var maxAcceleration: Double

    var body: some View {
        Form {
            Section(header: Text("Adjust Parameters")) {
                HStack {
                    Text("Speed Limit (km/h)")
                    Spacer()
                    TextField("Speed Limit", value: $speedLimit, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Max Acceleration (m/s²)")
                    Spacer()
                    TextField("Max Acceleration", value: $maxAcceleration, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// Preview
#Preview {
    ContentView()
}
